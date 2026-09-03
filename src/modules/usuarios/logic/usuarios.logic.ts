import {
  Injectable,
  ConflictException,
  BadRequestException,
  InternalServerErrorException,
} from '@nestjs/common';
import {
  mapActivateResult,
  mapDeleteResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { CreateUsuarioDto, UpdateUsuarioDto } from '../dto/usuarios.dto';
import { FiltroUsuarioDto } from '../dto/filtros-usuario.dto';
import { UsuariosModel } from '../models/usuarios.model';

@Injectable()
export class UsuariosLogic {
  constructor(private readonly usuariosModel: UsuariosModel) {}

  async listar(filtros: FiltroUsuarioDto) {
    const result = await this.usuariosModel.listar(filtros);
    return {
      data: result.registros ?? [],
      meta: {
        total: result.total ?? 0,
        limite: filtros.limite ?? 10,
        offset: filtros.offset ?? 0,
        resumen: result.resumen ?? { total: 0, activos: 0, inactivos: 0 },
      },
    };
  }

  async obtenerPorId(id: number) {
    const result = await this.usuariosModel.obtenerPorId(id);
    return mapSingleResult(result, `Usuario con ID ${id} no encontrado`);
  }

  async crear(dto: CreateUsuarioDto) {
    try {
      const passwordHash = await UsuariosModel.hashPassword(dto.password);
      const pinHash = dto.pin ? await UsuariosModel.hashPin(dto.pin) : null;

      const result = await this.usuariosModel.crear(
        dto.username,
        dto.email,
        passwordHash,
        dto.nombres,
        dto.apellidos,
        dto.telefono,
        pinHash,
        dto.idSucursalDefault ?? null,
        dto.rolesIds ?? [],
        dto.idUsuarioAuditoria,
      );
      return mapSingleResult(result, 'No se pudo crear el usuario');
    } catch (error: any) {
      this.handleDatabaseException(error);
    }
  }

  async actualizar(id: number, dto: UpdateUsuarioDto) {
    try {
      const passwordHash = dto.password
        ? await UsuariosModel.hashPassword(dto.password)
        : null;

      const pinHash = dto.pin
        ? await UsuariosModel.hashPin(dto.pin)
        : null;

      const result = await this.usuariosModel.actualizar(
        id,
        dto.username ?? null,
        dto.email ?? null,
        passwordHash,
        pinHash,
        dto.nombres ?? null,
        dto.apellidos ?? null,
        dto.telefono ?? null,
        dto.idSucursalDefault ?? null,
        dto.rolesIds ?? null,
        dto.idUsuarioAuditoria,
      );
      return mapSingleResult(result, `Usuario con ID ${id} no encontrado`);
    } catch (error: any) {
      this.handleDatabaseException(error);
    }
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    try {
      const result = await this.usuariosModel.eliminar(id, idUsuarioAuditoria);
      return mapDeleteResult(result, `Usuario con ID ${id} no encontrado o ya desactivado`);
    } catch (error: any) {
      this.handleDatabaseException(error);
    }
  }

  async activar(id: number, idUsuarioAuditoria?: number) {
    try {
      const result = await this.usuariosModel.activar(id, idUsuarioAuditoria);
      return mapActivateResult(result, `Usuario con ID ${id} no encontrado o ya activo`);
    } catch (error: any) {
      this.handleDatabaseException(error);
    }
  }

  private handleDatabaseException(error: any): never {
    if (error?.status && typeof error.getStatus === 'function') {
      throw error;
    }

    const rawMessage = error?.message || '';

    if (error?.code === 'P0001' || rawMessage) {
      const cleanMessage = rawMessage.replace(/^error:\s*/i, '').trim();

      if (cleanMessage.toLowerCase().includes('ya se encuentra registrado')) {
        throw new ConflictException(cleanMessage);
      }

      throw new BadRequestException(cleanMessage || 'Error al procesar la solicitud');
    }

    throw new InternalServerErrorException('Error interno al procesar la solicitud');
  }
}