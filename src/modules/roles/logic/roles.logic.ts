import { Injectable, BadRequestException } from '@nestjs/common';
import {
  mapActivateResult,
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  AsignarPermisosRolDto,
  AsignarRolesUsuarioDto,
  CreateRolDto,
  UpdateRolDto,
} from '../dto/roles.dto';
import { FiltroRolDto } from '../dto/filtros-rol.dto';
import { RolesModel } from '../models/roles.model';

@Injectable()
export class RolesLogic {
  constructor(private readonly rolesModel: RolesModel) {}

  async listar(filtros: FiltroRolDto, idEmpresa?: number | null) {
    const result = await this.rolesModel.listar(filtros, idEmpresa);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number, idEmpresa?: number | null) {
    const result = await this.rolesModel.obtenerPorId(id, idEmpresa);
    return mapSingleResult(result, `Rol con ID ${id} no encontrado`);
  }

  async crear(dto: CreateRolDto, idEmpresa?: number | null) {
    const result = await this.rolesModel.crear(
      dto.nombre,
      dto.descripcion,
      dto.idUsuarioAuditoria,
      idEmpresa,
    );
    return mapSingleResult(result, 'No se pudo crear el rol');
  }

  async actualizar(id: number, dto: UpdateRolDto, idEmpresa?: number | null) {
    const result = await this.rolesModel.actualizar(
      id,
      dto.nombre ?? null,
      dto.descripcion ?? null,
      dto.idUsuarioAuditoria,
      idEmpresa,
    );
    return mapSingleResult(result, `Rol con ID ${id} no encontrado`);
  }

  async eliminar(
    id: number,
    idUsuarioAuditoria?: number,
    idEmpresa?: number | null,
  ) {
    const result = await this.rolesModel.eliminar(
      id,
      idUsuarioAuditoria,
      idEmpresa,
    );
    return mapDeleteResult(
      result,
      `Rol con ID ${id} no encontrado o ya desactivado`,
    );
  }

  async activar(
    id: number,
    idUsuarioAuditoria?: number,
    idEmpresa?: number | null,
  ) {
    const result = await this.rolesModel.activar(
      id,
      idUsuarioAuditoria,
      idEmpresa,
    );
    return mapActivateResult(
      result,
      `Rol con ID ${id} no encontrado o ya activo`,
    );
  }

  async asignarPermisos(
    id: number,
    dto: AsignarPermisosRolDto,
    idEmpresa?: number | null,
  ) {
    const result = await this.rolesModel.asignarPermisos(
      id,
      dto.idsPermisos,
      dto.idUsuarioAuditoria,
      idEmpresa,
    );
    return mapSingleResult(
      result,
      `No se pudieron asignar los permisos al rol ${id}`,
    );
  }

  async asignarRolesAUsuario(
    idUsuario: number,
    dto: AsignarRolesUsuarioDto,
    idEmpresa?: number | null,
  ) {
    const result = await this.rolesModel.asignarRolesAUsuario(
      idUsuario,
      dto.idsRoles,
      dto.idUsuarioAuditoria,
      idEmpresa,
    );

    if (result.error) {
      throw new BadRequestException(result.error);
    }

    if (!result.actualizado) {
      throw new BadRequestException(
        `No se pudieron asignar los roles al usuario ${idUsuario}`,
      );
    }

    return {
      actualizado: true,
      idUsuario: result.id_usuario,
    };
  }
}
