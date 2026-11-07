import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import { AuthSingleResult } from '../../../common/interfaces/auth-db.interface';
import {
  CreateTipoProductoDto,
  ImpactoTipoProducto,
  TipoProducto,
  UpdatePermisosTipoProductoDto,
} from '../dto/tipos-producto.dto';

@Injectable()
export class TiposProductoModel {
  constructor(private readonly db: DatabaseService) {}
  listar(idEmpresa?: number | null) {
    return this.db.callFunctionJson<TipoProducto[]>(
      'pro_listar_tipos_producto',
      [idEmpresa ?? null],
    );
  }
  impacto(id: number, idEmpresa?: number | null) {
    return this.db.callFunctionJson<AuthSingleResult<ImpactoTipoProducto>>(
      'pro_impacto_tipo_producto',
      [id, idEmpresa ?? null],
    );
  }
  actualizarPermisos(
    id: number,
    dto: UpdatePermisosTipoProductoDto,
    idEmpresa?: number | null,
  ) {
    return this.db.callFunctionJson<AuthSingleResult<TipoProducto>>(
      'pro_actualizar_tipo_producto',
      [
        id,
        dto.permite_venta,
        dto.requiere_receta,
        dto.requiere_estacion,
        dto.permite_stock_inicial,
        dto.idUsuarioAuditoria ?? null,
        idEmpresa ?? null,
      ],
    );
  }
  crear(dto: CreateTipoProductoDto, idEmpresa?: number | null) {
    return this.db.callFunctionJson<AuthSingleResult<TipoProducto>>(
      'pro_crear_tipo_producto',
      [
        dto.nombre,
        dto.permite_venta,
        dto.requiere_receta,
        dto.requiere_estacion,
        dto.permite_stock_inicial,
        dto.idUsuarioAuditoria ?? null,
        idEmpresa ?? null,
      ],
    );
  }
}
