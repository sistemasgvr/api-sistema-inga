import {
  Injectable,
  ConflictException,
  BadRequestException,
  InternalServerErrorException,
  NotFoundException,
} from '@nestjs/common';
import {
  mapActivateResult,
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { CreateUsuarioDto, UpdateUsuarioDto } from '../dto/usuarios.dto';
import { FiltroUsuarioDto } from '../dto/filtros-usuario.dto';
import { UsuariosModel } from '../models/usuarios.model';

@Injectable()
export class UsuariosLogic {
  constructor(private readonly usuariosModel: UsuariosModel) {}

  trabajadoresDisponibles() {
    return this.usuariosModel.trabajadoresDisponibles();
  }

  async trabajadorDisponible(id: number) {
    const [trabajador] = await this.usuariosModel.trabajadoresDisponibles(id);
    if (!trabajador)
      throw new NotFoundException(
        'El trabajador ya tiene usuario, está inactivo o no tiene correo.',
      );
    return trabajador;
  }

  async listar(filtros: FiltroUsuarioDto) {
    const result = await this.usuariosModel.listar(filtros);
    return mapListResult(result, filtros);
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
        dto.idTrabajador,
        passwordHash,
        pinHash,
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

      const pinHash = dto.pin ? await UsuariosModel.hashPin(dto.pin) : null;

      const result = await this.usuariosModel.actualizar(
        id,
        dto.username ?? null,
        passwordHash,
        pinHash,
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
      return mapDeleteResult(
        result,
        `Usuario con ID ${id} no encontrado o ya desactivado`,
      );
    } catch (error: any) {
      this.handleDatabaseException(error);
    }
  }

  async activar(id: number, idUsuarioAuditoria?: number) {
    try {
      const result = await this.usuariosModel.activar(id, idUsuarioAuditoria);
      return mapActivateResult(
        result,
        `Usuario con ID ${id} no encontrado o ya activo`,
      );
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

      throw new BadRequestException(
        cleanMessage || 'Error al procesar la solicitud',
      );
    }

    throw new InternalServerErrorException(
      'Error interno al procesar la solicitud',
    );
  }
}
