import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
  AuthActivateResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import { CreateProductoDto, FiltroProductosDto, ProductoEstadoFiltro, UpdateProductoDto } from '../dto/productos.dto';

@Injectable()
export class ProductosModel {
  constructor(private readonly db: DatabaseService) {}

  private resolveEstadoFiltro(estado?: ProductoEstadoFiltro): number | null {
    if (estado === 'inactivos') return 0;
    if (estado === 'todos') return null;
    return 1;
  }

  listar(filtros: FiltroProductosDto) {
    return this.db.callFunctionJson<AuthListResult>('pro_listar_productos', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset ?? 0,
      filtros.tipo_producto ?? null,
      filtros.id_subcategoria ?? null,
      filtros.id_categoria ?? null,
      this.resolveEstadoFiltro(filtros.estado),
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_obtener_producto', [id]);
  }

  listarUnidadesMedida() {
    return this.db.callFunctionJson<any>('pro_listar_unidades_medida', []);
  }

  crear(dto: CreateProductoDto) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_crear_producto', [
      dto.id_subcategoria,
      dto.id_unidad_medida,
      dto.codigo_interno,
      dto.nombre,
      dto.tipo_producto,
      dto.id_estacion ?? null,
      dto.id_almacen_stock ?? null,
      dto.descripcion ?? null,
      dto.precio_venta ?? 0,
      dto.afecto_igv ?? true,
      dto.controla_stock ?? false,
      dto.disponible_venta ?? true,
      dto.tiempo_prep_min ?? null,
      dto.imagen_url ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(id: number, dto: UpdateProductoDto) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_actualizar_producto', [
      id,
      dto.id_subcategoria ?? null,
      dto.id_unidad_medida ?? null,
      dto.id_estacion ?? null,
      dto.id_almacen_stock ?? null,
      dto.codigo_interno ?? null,
      dto.nombre ?? null,
      dto.descripcion ?? null,
      dto.tipo_producto ?? null,
      dto.precio_venta ?? null,
      dto.afecto_igv ?? null,
      dto.controla_stock ?? null,
      dto.disponible_venta ?? null,
      dto.tiempo_prep_min ?? null,
      dto.imagen_url ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  toggleDisponibilidad(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_toggle_disponibilidad_producto', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('pro_eliminar_producto', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  activar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthActivateResult>('pro_activar_producto', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}