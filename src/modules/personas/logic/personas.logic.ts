import { Injectable } from '@nestjs/common';
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

@Injectable()
export class PersonasLogic {
  constructor(private readonly personasModel: PersonasModel) {}

  /**
   * Limpia los campos según el tipo de persona antes de mandarlos a la base.
   *
   * Lo hago porque el formulario del front muestra unos campos u otros según se
   * elija natural o jurídica, pero si el usuario llena "nombres", se arrepiente
   * y cambia a jurídica, el valor viejo igual viaja en el request. Sin esta
   * limpieza terminaría guardando una empresa con nombre de persona, y la ficha
   * quedaría mostrando datos contradictorios.
   *
   * Es una decisión de presentación, no una regla de negocio: por eso va acá y
   * no en la función SQL, que se limita a validar y guardar.
   */
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

  async listar(filtros: FiltroPersonasDto) {
    const result = await this.personasModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async buscar(dto: BuscarPersonasDto) {
    return await this.personasModel.buscar(dto);
  }

  async obtenerPorId(id: number) {
    const result = await this.personasModel.obtenerPorId(id);
    return mapSingleResult(result, `Persona con ID ${id} no encontrada`);
  }

  async crear(dto: CreatePersonaDto) {
    const datos = this.normalizarPorTipo(dto.tipo_persona, {
      tipoPersona: dto.tipo_persona,
      tipoDocumento: dto.tipo_documento,
      numDocumento: dto.num_documento,
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

    const result = await this.personasModel.crear(datos, dto.idUsuarioAuditoria);
    return mapSingleResult(result, 'No se pudo crear la persona');
  }

  async actualizar(id: number, dto: UpdatePersonaDto) {
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
    );
    return mapSingleResult(result, `Persona con ID ${id} no encontrada`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.personasModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(
      result,
      `Persona con ID ${id} no encontrada o ya inactiva`,
    );
  }

  async activar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.personasModel.activar(id, idUsuarioAuditoria);
    return mapActivateResult(
      result,
      `Persona con ID ${id} no encontrada o ya activa`,
    );
  }
}
