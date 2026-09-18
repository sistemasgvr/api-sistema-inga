import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  AbrirDiaDto,
  CreateInsumoDto,
  CreateLineaDto,
  FiltroDiasDto,
  FiltroInsumosDto,
  FiltroReporteDiaDto,
  InsumoEstadoFiltro,
  UpdateInsumoDto,
} from '../dto/gastos-diarios.dto';

/**
 * Capa que habla con la base. No decide nada: traduce los datos a los
 * parámetros que espera cada función SQL, en el orden correcto.
 * Toda la regla de negocio vive en las funciones `gdo_*`.
 */
@Injectable()
export class GastosDiariosModel {
  constructor(private readonly db: DatabaseService) {}

  private resolveEstadoFiltro(estado?: InsumoEstadoFiltro): number | null {
    if (estado === 'inactivos') return 0;
    if (estado === 'todos') return null;
    return 1;
  }

  /* -------------------------------- Insumos -------------------------------- */

  listarInsumos(filtros: FiltroInsumosDto) {
    return this.db.callFunctionJson<{ registros: unknown[]; resumen: unknown }>(
      'gdo_listar_insumos',
      [
        filtros.buscar ?? '',
        filtros.id_categoria ?? null,
        this.resolveEstadoFiltro(filtros.estado),
      ],
    );
  }

  obtenerInsumo(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('gdo_obtener_insumo', [id]);
  }

  crearInsumo(dto: CreateInsumoDto) {
    return this.db.callFunctionJson<AuthSingleResult>('gdo_crear_insumo', [
      dto.id_categoria,
      dto.nombre,
      dto.precio_referencial ?? 0,
      dto.id_proveedor_habitual ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  actualizarInsumo(id: number, dto: UpdateInsumoDto) {
    return this.db.callFunctionJson<AuthSingleResult>('gdo_actualizar_insumo', [
      id,
      dto.id_categoria ?? null,
      dto.nombre ?? null,
      // `?? null` y no `|| null`: un precio de 0 es válido.
      dto.precio_referencial ?? null,
      dto.id_proveedor_habitual ?? null,
      dto.quitar_proveedor ?? false,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  toggleInsumo(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('gdo_toggle_insumo', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  /* ------------------------------ Gasto del día ---------------------------- */

  abrirDia(dto: AbrirDiaDto) {
    return this.db.callFunctionJson<AuthSingleResult>('gdo_abrir_dia', [
      dto.fecha_gasto ?? null,
      dto.id_sucursal ?? null,
      dto.id_turno ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  obtenerDia(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('gdo_obtener_dia', [id]);
  }

  listarDias(filtros: FiltroDiasDto) {
    return this.db.callFunctionJson<AuthListResult>('gdo_listar_dias', [
      filtros.limite ?? 10,
      filtros.offset ?? 0,
      filtros.anio ?? null,
      filtros.mes ?? null,
      filtros.fecha_desde ?? null,
      filtros.fecha_hasta ?? null,
    ]);
  }

  agregarLinea(idGastoDia: number, dto: CreateLineaDto) {
    return this.db.callFunctionJson<AuthSingleResult>('gdo_agregar_linea', [
      idGastoDia,
      dto.id_insumo,
      dto.cantidad,
      dto.precio_unitario,
      dto.forma_pago ?? 1,
      dto.id_unidad_medida ?? null,
      dto.id_proveedor ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  anularLinea(id: number, motivo?: string, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthSingleResult>('gdo_anular_linea', [
      id,
      motivo ?? null,
      idUsuarioAuditoria ?? null,
    ]);
  }

  reporteDia(filtros: FiltroReporteDiaDto) {
    return this.db.callFunctionJson<AuthSingleResult>('gdo_reporte_dia', [
      filtros.fecha_gasto ?? null,
      filtros.id_sucursal ?? null,
    ]);
  }
}
