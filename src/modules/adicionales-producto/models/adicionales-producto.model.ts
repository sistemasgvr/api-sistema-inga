import { Injectable } from '@nestjs/common';
import { AuthDeleteResult, AuthSingleResult } from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import { CreateAdicionalDto, UpdateAdicionalDto } from '../dto/adicionales-producto.dto';

@Injectable()
export class AdicionalesProductoModel {
  constructor(private readonly db: DatabaseService) {}

  listarPorProducto(idProducto: number) {
    return this.db.callFunctionJson<any>('pro_listar_adicionales_producto', [idProducto]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_obtener_adicional', [id]);
  }

  crear(idProducto: number, dto: CreateAdicionalDto) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_crear_adicional', [
      idProducto,
      dto.nombre,
      dto.precio_adicional ?? 0,
      dto.id_producto_insumo ?? null,
      dto.cantidad_insumo ?? 0,
      dto.id_unidad_medida ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(id: number, dto: UpdateAdicionalDto) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_actualizar_adicional', [
      id,
      dto.nombre ?? null,
      dto.precio_adicional ?? null,
      dto.id_producto_insumo ?? null,
      dto.cantidad_insumo ?? null,
      dto.id_unidad_medida ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('pro_eliminar_adicional', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}