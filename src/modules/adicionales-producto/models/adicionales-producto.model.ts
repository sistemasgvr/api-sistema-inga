import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  CreateAdicionalDto,
  UpdateAdicionalDto,
} from '../dto/adicionales-producto.dto';

@Injectable()
export class AdicionalesProductoModel {
  constructor(private readonly db: DatabaseService) {}

  listarPorProducto(idProducto: number, idEmpresa?: number | null) {
    return this.db.callFunctionJson<any>('pro_listar_adicionales_producto', [
      idProducto,
      idEmpresa ?? null,
    ]);
  }

  obtenerPorId(id: number, idEmpresa?: number | null) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_obtener_adicional', [
      id,
      idEmpresa ?? null,
    ]);
  }

  crear(
    idProducto: number,
    dto: CreateAdicionalDto,
    idEmpresa?: number | null,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_crear_adicional', [
      idProducto,
      dto.nombre,
      dto.precio_adicional ?? 0,
      dto.id_producto_insumo ?? null,
      dto.cantidad_insumo ?? 0,
      dto.id_unidad_medida ?? null,
      dto.idUsuarioAuditoria ?? null,
      idEmpresa ?? null,
    ]);
  }

  actualizar(id: number, dto: UpdateAdicionalDto, idEmpresa?: number | null) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'pro_actualizar_adicional',
      [
        id,
        dto.nombre ?? null,
        dto.precio_adicional ?? null,
        dto.id_producto_insumo ?? null,
        dto.cantidad_insumo ?? null,
        dto.id_unidad_medida ?? null,
        dto.idUsuarioAuditoria ?? null,
        idEmpresa ?? null,
      ],
    );
  }

  eliminar(id: number, idUsuarioAuditoria?: number, idEmpresa?: number | null) {
    return this.db.callFunctionJson<AuthDeleteResult>(
      'pro_eliminar_adicional',
      [id, idUsuarioAuditoria ?? null, idEmpresa ?? null],
    );
  }
}
