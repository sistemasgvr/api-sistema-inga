import { Injectable, Logger } from '@nestjs/common';
import {
  mapActivateResult,
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  BuscarPersonasDto,
  CreatePersonaDto,
  FiltroPersonasDto,
  TIPO_PERSONA,
  UpdatePersonaDto,
} from '../dto/personas.dto';
import { PersonaDbParams, PersonasModel } from '../models/personas.model';
import { ConsultaDocumentoLogic } from './consulta-documento.logic';

@Injectable()
export class PersonasLogic {
  private readonly logger = new Logger(PersonasLogic.name);

  constructor(
    private readonly personasModel: PersonasModel,
    private readonly consulta: ConsultaDocumentoLogic,
  ) {}

  private normalizarPorTipo(
    tipoPersona: number | null,
    datos: PersonaDbParams,
  ): PersonaDbParams {
    if (tipoPersona === TIPO_PERSONA.JURIDICA) {
      return {
        ...datos,
        nombres: null,
        apellidoPaterno: null,
        apellidoMaterno: null,
      };
    }

    if (tipoPersona === TIPO_PERSONA.NATURAL) {
      return { ...datos, razonSocial: null };
    }

    // Si no sé el tipo (update parcial que no lo manda), no toco nada:
    // la función SQL mezclará con lo guardado y validará el resultado final.
    return datos;
  }

  async listar(filtros: FiltroPersonasDto, idEmpresa?: number | null) {
    const result = await this.personasModel.listar(filtros, idEmpresa);
    return mapListResult(result, filtros);
  }

  async buscar(dto: BuscarPersonasDto, idEmpresa?: number | null) {
    return await this.personasModel.buscar(dto, idEmpresa);
  } 
  async asegurarClientePorDocumento(
    numero: string | null | undefined,
    idEmpresa?: number | null,
    idUsuarioAuditoria?: number,
  ): Promise<number | null> {
    const documento = (numero ?? '').trim();
    // Solo DNI o RUC. «00000000» es el genérico de Clientes varios: ya existe.
    if (!/^\d{8}$/.test(documento) && !/^\d{11}$/.test(documento)) return null;
    if (documento === '00000000') return null;

    const existente = await this.buscarPorDocumento(documento, idEmpresa);
    if (existente) return existente.es_cliente ? existente.id : null;

    try {
      const consulta = await this.consulta.consultar(
        documento,
        idEmpresa ?? null,
      );
      if (consulta.origen === 'registrado') return consulta.id_persona;

      // El tipo sale del documento, no de SUNAT: un RUC que empieza en 10 es una
      // persona natural con negocio, pero para el comprobante es una jurídica y
      // sus datos vienen como razón social (sin nombres, que es lo que exige la
      // validación de persona natural).
      const esRuc = documento.length === 11;

      const creada = (await this.crear(
        {
          tipo_persona: esRuc ? TIPO_PERSONA.JURIDICA : TIPO_PERSONA.NATURAL,
          tipo_documento: consulta.tipo_documento,
          num_documento: documento,
          razon_social: esRuc
            ? (consulta.razon_social ?? consulta.nombre)
            : undefined,
          nombres: consulta.nombres ?? undefined,
          apellido_paterno: consulta.apellido_paterno ?? undefined,
          apellido_materno: consulta.apellido_materno ?? undefined,
          direccion: consulta.direccion ?? undefined,
          id_distrito: consulta.distrito?.id,
          es_cliente: true,
          es_proveedor: false,
          idUsuarioAuditoria,
        },
        idEmpresa,
      )) as { id?: number } | null;

      return creada?.id ?? null;
    } catch (error) {
      // Dos cobros simultáneos del mismo documento: el otro ya la creó.
      if ((error as { code?: string }).code === '23505') {
        const otra = await this.buscarPorDocumento(documento, idEmpresa);
        if (otra) return otra.es_cliente ? otra.id : null;
      }
      this.logger.warn(
        `No se pudo crear el cliente ${documento} al cobrar: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
      return null;
    }
  }

  private async buscarPorDocumento(
    documento: string,
    idEmpresa?: number | null,
  ): Promise<{ id: number; es_cliente: boolean } | null> {
    const { registros = [] } =
      (await this.personasModel.buscar(
        { buscar: documento, limite: 10 },
        idEmpresa,
      )) ?? {};

    const encontrada = (
      registros as {
        id: number;
        num_documento: string | null;
        es_cliente: boolean;
      }[]
    ).find((p) => p.num_documento === documento);

    return encontrada
      ? { id: encontrada.id, es_cliente: encontrada.es_cliente }
      : null;
  }

  async obtenerPorId(id: number, idEmpresa?: number | null) {
    const result = await this.personasModel.obtenerPorId(id, idEmpresa);
    return mapSingleResult(result, `Persona con ID ${id} no encontrada`);
  }

  async crear(dto: CreatePersonaDto, idEmpresa?: number | null) {
    const datos = this.normalizarPorTipo(dto.tipo_persona, {
      tipoPersona: dto.tipo_persona,
      tipoDocumento: dto.tipo_documento ?? null,
      numDocumento: dto.num_documento ?? null,
      razonSocial: dto.razon_social ?? null,
      nombres: dto.nombres ?? null,
      apellidoPaterno: dto.apellido_paterno ?? null,
      apellidoMaterno: dto.apellido_materno ?? null,
      direccion: dto.direccion ?? null,
      idDistrito: dto.id_distrito ?? null,
      telefono: dto.telefono ?? null,
      email: dto.email ?? null,
      esCliente: dto.es_cliente ?? false,
      esProveedor: dto.es_proveedor ?? false,
      idConvenio: dto.id_convenio ?? null,
    });

    const result = await this.personasModel.crear(
      datos,
      dto.idUsuarioAuditoria,
      idEmpresa,
    );
    return mapSingleResult(result, 'No se pudo crear la persona');
  }

  async actualizar(
    id: number,
    dto: UpdatePersonaDto,
    idEmpresa?: number | null,
  ) {
    const datos = this.normalizarPorTipo(dto.tipo_persona ?? null, {
      tipoPersona: dto.tipo_persona ?? null,
      tipoDocumento: dto.tipo_documento ?? null,
      numDocumento: dto.num_documento ?? null,
      razonSocial: dto.razon_social ?? null,
      nombres: dto.nombres ?? null,
      apellidoPaterno: dto.apellido_paterno ?? null,
      apellidoMaterno: dto.apellido_materno ?? null,
      direccion: dto.direccion ?? null,
      idDistrito: dto.id_distrito ?? null,
      telefono: dto.telefono ?? null,
      email: dto.email ?? null,
      esCliente: dto.es_cliente ?? null,
      esProveedor: dto.es_proveedor ?? null,
      idConvenio: dto.id_convenio ?? null,
    });

    const result = await this.personasModel.actualizar(
      id,
      datos,
      dto.quitar_convenio ?? false,
      dto.idUsuarioAuditoria,
      idEmpresa,
    );
    return mapSingleResult(result, `Persona con ID ${id} no encontrada`);
  }

  async eliminar(
    id: number,
    idUsuarioAuditoria?: number,
    idEmpresa?: number | null,
  ) {
    const result = await this.personasModel.eliminar(
      id,
      idUsuarioAuditoria,
      idEmpresa,
    );
    return mapDeleteResult(
      result,
      `Persona con ID ${id} no encontrada o ya inactiva`,
    );
  }

  async activar(
    id: number,
    idUsuarioAuditoria?: number,
    idEmpresa?: number | null,
  ) {
    const result = await this.personasModel.activar(
      id,
      idUsuarioAuditoria,
      idEmpresa,
    );
    return mapActivateResult(
      result,
      `Persona con ID ${id} no encontrada o ya activa`,
    );
  }
}
