import {
  BadGatewayException,
  BadRequestException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ApisPeruConsultasService } from '../../../integrations/apisperu/apisperu-consultas.service';
import { ApisPeruFallo } from '../../../integrations/apisperu/apisperu.service';
import { TIPO_DOCUMENTO, TIPO_PERSONA } from '../dto/personas.dto';
import { PersonasModel } from '../models/personas.model';

export type DistritoConsulta = {
  id: number;
  ubigeo: string;
  distrito: string;
  provincia: string;
  departamento: string;
};

export type ConsultaDocumento = {
  origen: 'registrado' | 'reniec' | 'sunat';
  id_persona: number | null;
  tipo_persona: number;
  tipo_documento: number;
  num_documento: string;
  nombre: string;
  razon_social: string | null;
  nombres: string | null;
  apellido_paterno: string | null;
  apellido_materno: string | null;
  nombre_comercial: string | null;
  direccion: string | null;
  distrito: DistritoConsulta | null;
  estado: string | null;
  condicion: string | null;
  es_cliente: boolean;
};

type PersonaRegistrada = {
  id: number;
  tipo_persona: number;
  tipo_documento: number;
  num_documento: string;
  razon_social: string | null;
  nombres: string | null;
  apellido_paterno: string | null;
  apellido_materno: string | null;
  nombre_completo: string | null;
  direccion: string | null;
  id_distrito: number | null;
  es_cliente: boolean;
};

const limpio = (v: string | null | undefined) => v?.trim() || null;

@Injectable()
export class ConsultaDocumentoLogic {
  constructor(
    private readonly personasModel: PersonasModel,
    private readonly consultas: ApisPeruConsultasService,
  ) {}

  async consultar(
    numero: string,
    idEmpresa: number | null,
  ): Promise<ConsultaDocumento> {
    const esRuc = /^\d{11}$/.test(numero);
    if (!esRuc && !/^\d{8}$/.test(numero))
      throw new BadRequestException(
        'Ingresa un DNI de 8 dígitos o un RUC de 11 dígitos',
      );

    const registrado = await this.registrado(numero, idEmpresa);
    if (registrado) return registrado;

    try {
      return esRuc ? await this.ruc(numero) : await this.dni(numero);
    } catch (error) {
      if (!(error instanceof ApisPeruFallo)) throw error;
      if (error.status === 404) throw new NotFoundException(error.message);
      if (error.status === null && !error.reintentable)
        throw new ServiceUnavailableException(error.message);
      throw new BadGatewayException(error.message);
    }
  }

  private async registrado(
    numero: string,
    idEmpresa: number | null,
  ): Promise<ConsultaDocumento | null> {
    const { registros = [] } =
      (await this.personasModel.buscar(
        { buscar: numero, limite: 10 },
        idEmpresa,
      )) ?? {};
    const coincidencia = (
      registros as { id: number; num_documento: string }[]
    ).find((p) => p.num_documento === numero);
    if (!coincidencia) return null;
    const result = await this.personasModel.obtenerPorId(
      coincidencia.id,
      idEmpresa,
    );
    const p = result?.registro as PersonaRegistrada | null;
    if (!p) return null;
    const distrito = p.id_distrito
      ? await this.distritoPorId(p.id_distrito)
      : null;
    return {
      origen: 'registrado',
      id_persona: p.id,
      tipo_persona: p.tipo_persona,
      tipo_documento: p.tipo_documento,
      num_documento: p.num_documento,
      nombre: p.nombre_completo ?? p.razon_social ?? p.num_documento,
      razon_social: p.razon_social,
      nombres: p.nombres,
      apellido_paterno: p.apellido_paterno,
      apellido_materno: p.apellido_materno,
      nombre_comercial: null,
      direccion: p.direccion,
      distrito,
      estado: null,
      condicion: null,
      es_cliente: p.es_cliente,
    };
  }

  private async dni(numero: string): Promise<ConsultaDocumento> {
    const d = await this.consultas.dni(numero);
    const nombres = limpio(d.nombres);
    const paterno = limpio(d.apellidoPaterno);
    const materno = limpio(d.apellidoMaterno);
    return {
      origen: 'reniec',
      id_persona: null,
      tipo_persona: TIPO_PERSONA.NATURAL,
      tipo_documento: TIPO_DOCUMENTO.DNI,
      num_documento: numero,
      nombre: [nombres, paterno, materno].filter(Boolean).join(' ') || numero,
      razon_social: null,
      nombres,
      apellido_paterno: paterno,
      apellido_materno: materno,
      nombre_comercial: null,
      direccion: null,
      distrito: null,
      estado: null,
      condicion: null,
      es_cliente: false,
    };
  }

  private async ruc(numero: string): Promise<ConsultaDocumento> {
    const r = await this.consultas.ruc(numero);
    const ubigeo = limpio(r.ubigeo);
    const distrito = ubigeo
      ? (((await this.personasModel.distritoPorUbigeo(ubigeo))
          ?.registro as DistritoConsulta | null) ?? null)
      : null;
    const natural = numero.startsWith('10');
    return {
      origen: 'sunat',
      id_persona: null,
      tipo_persona: natural ? TIPO_PERSONA.NATURAL : TIPO_PERSONA.JURIDICA,
      tipo_documento: TIPO_DOCUMENTO.RUC,
      num_documento: numero,
      nombre: limpio(r.razonSocial) ?? numero,
      razon_social: limpio(r.razonSocial),
      nombres: null,
      apellido_paterno: null,
      apellido_materno: null,
      nombre_comercial:
        limpio(r.nombreComercial) === '-' ? null : limpio(r.nombreComercial),
      direccion: limpio(r.direccion),
      distrito,
      estado: limpio(r.estado),
      condicion: limpio(r.condicion),
      es_cliente: false,
    };
  }

  private async distritoPorId(id: number): Promise<DistritoConsulta | null> {
    const r = (await this.personasModel.distrito(id))?.registro as
      (Omit<DistritoConsulta, 'ubigeo'> & { codigo_ubigeo: string }) | null;
    if (!r) return null;
    const { codigo_ubigeo, ...resto } = r;
    return { ...resto, ubigeo: codigo_ubigeo };
  }
}
