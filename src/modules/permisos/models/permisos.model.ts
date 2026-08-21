import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import { AuthListResult } from '../../../common/interfaces/auth-db.interface';
import { FiltroPermisoDto } from '../dto/filtros-permiso.dto';

export interface PermisoItem {
  id: number;
  codigo: string;
  nombre: string;
  descripcion: string | null;
  modulo: string;
  estado: number;
}

@Injectable()
export class PermisosModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroPermisoDto) {
    return this.db.callFunctionJson<AuthListResult<PermisoItem>>('auth_listar_permisos', [
      filtros.buscar ?? '',
      filtros.modulo ?? null,
    ]);
  }
}