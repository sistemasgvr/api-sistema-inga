import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import { AuthSingleResult } from '../../../common/interfaces/auth-db.interface';
import { CreateTipoProductoDto, TipoProducto } from '../dto/tipos-producto.dto';

@Injectable()
export class TiposProductoModel {
  constructor(private readonly db: DatabaseService) {}
  listar() {
    return this.db.callFunctionJson<TipoProducto[]>(
      'pro_listar_tipos_producto',
      [],
    );
  }
  crear(dto: CreateTipoProductoDto) {
    return this.db.callFunctionJson<AuthSingleResult<TipoProducto>>(
      'pro_crear_tipo_producto',
      [
        dto.nombre,
        dto.permite_venta,
        dto.requiere_receta,
        dto.requiere_estacion,
        dto.permite_stock_inicial,
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }
}
