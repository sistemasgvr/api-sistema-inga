import { Injectable } from '@nestjs/common';
import { AuthDeleteResult, AuthSingleResult } from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import { CreateRecetaDto, GuardarRecetaInsumoDto } from '../dto/recetas-producto.dto';

@Injectable()
export class RecetasProductoModel {
  constructor(private readonly db: DatabaseService) {}

  listarPorProducto(idProducto: number) {
    return this.db.callFunctionJson<any>('pro_listar_recetas_producto', [idProducto]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_obtener_receta', [id]);
  }

  listarInsumosProcesados(busqueda: string) {
    return this.db.callFunctionJson<any>('pro_listar_insumos_procesados', [busqueda ?? '']);
  }

  crearReceta(idProducto: number, dto: CreateRecetaDto) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_crear_receta', [
      idProducto,
      dto.nombre ?? null,
      dto.rendimiento_porciones ?? 1,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  guardarInsumo(idReceta: number, dto: GuardarRecetaInsumoDto) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_guardar_receta_insumo', [
      idReceta,
      dto.id_producto_insumo,
      dto.cantidad,
      dto.id_unidad_medida,
      dto.porcentaje_merma ?? 0,
      dto.es_opcional ?? false,
      dto.grupo_sustitucion ?? null,
      dto.orden ?? 0,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  eliminarInsumo(idInsumoReceta: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_eliminar_receta_insumo', [
      idInsumoReceta,
      idUsuarioAuditoria ?? null,
    ]);
  }

  eliminarReceta(idReceta: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('pro_eliminar_receta', [
      idReceta,
      idUsuarioAuditoria ?? null,
    ]);
  }
}