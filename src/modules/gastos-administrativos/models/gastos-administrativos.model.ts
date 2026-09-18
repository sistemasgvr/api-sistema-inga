import { Injectable } from '@nestjs/common';
import {
  AuthActivateResult,
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  CreateCategoriaGastoDto,
  CreateGastoDto,
  FiltroCategoriasGastoDto,
  FiltroGastosDto,
  FiltroReporteMensualDto,
  GastoEstadoFiltro,
  UpdateCategoriaGastoDto,
  UpdateGastoDto,
} from '../dto/gastos-administrativos.dto';

/**
 * Capa que habla con la base. No decide nada: traduce los datos a los
 * parámetros que espera cada función SQL, en el orden correcto.
 * Toda la regla de negocio vive en las funciones `gad_*`.
 */
@Injectable()
export class GastosAdministrativosModel {
  constructor(private readonly db: DatabaseService) {}

  private resolveEstadoFiltro(estado?: GastoEstadoFiltro): number | null {
    if (estado === 'inactivos') return 0;
    if (estado === 'todos') return null;
    return 1;
  }

  /* ------------------------------ Categorías ------------------------------ */

  listarCategorias(filtros: FiltroCategoriasGastoDto) {
    return this.db.callFunctionJson<{ registros: unknown[]; resumen: unknown }>(
      'gad_listar_categorias',
      [filtros.tipo_gasto ?? null, this.resolveEstadoFiltro(filtros.estado)],
    );
  }

  obtenerCategoria(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('gad_obtener_categoria', [id]);
  }

  crearCategoria(dto: CreateCategoriaGastoDto) {
    return this.db.callFunctionJson<AuthSingleResult>('gad_crear_categoria', [
      dto.codigo,
      dto.nombre,
      dto.tipo_gasto ?? 1,
      dto.id_categoria_padre ?? null,
      dto.orden ?? 0,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  actualizarCategoria(id: number, dto: UpdateCategoriaGastoDto) {
    return this.db.callFunctionJson<AuthSingleResult>('gad_actualizar_categoria', [
      id,
      dto.codigo ?? null,
      dto.nombre ?? null,
      dto.tipo_gasto ?? null,
      // `?? null` y no `|| null`: un orden de 0 es válido y con `||` se
      // convertiría en null, dejando el valor anterior sin cambiar.
      dto.orden ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  eliminarCategoria(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('gad_eliminar_categoria', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  activarCategoria(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthActivateResult>('gad_activar_categoria', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  /* -------------------------------- Gastos -------------------------------- */

  listarGastos(filtros: FiltroGastosDto) {
    return this.db.callFunctionJson<AuthListResult>('gad_listar_gastos', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset ?? 0,
      filtros.id_categoria ?? null,
      filtros.tipo_gasto ?? null,
      filtros.anio ?? null,
      filtros.mes ?? null,
      filtros.medio_pago ?? null,
      filtros.fecha_desde ?? null,
      filtros.fecha_hasta ?? null,
    ]);
  }

  obtenerGasto(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('gad_obtener_gasto', [id]);
  }

  registrarGasto(dto: CreateGastoDto) {
    return this.db.callFunctionJson<AuthSingleResult>('gad_registrar_gasto', [
      dto.id_categoria,
      dto.concepto,
      dto.monto,
      dto.fecha_gasto ?? null,
      dto.medio_pago ?? 1,
      dto.id_turno ?? null,
      dto.id_persona ?? null,
      dto.num_comprobante ?? null,
      dto.id_sucursal ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  actualizarGasto(id: number, dto: UpdateGastoDto) {
    return this.db.callFunctionJson<AuthSingleResult>('gad_actualizar_gasto', [
      id,
      dto.id_categoria ?? null,
      dto.concepto ?? null,
      dto.monto ?? null,
      dto.fecha_gasto ?? null,
      dto.medio_pago ?? null,
      dto.id_persona ?? null,
      dto.num_comprobante ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  anularGasto(id: number, motivo?: string, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('gad_anular_gasto', [
      id,
      motivo ?? null,
      idUsuarioAuditoria ?? null,
    ]);
  }

  reporteMensual(filtros: FiltroReporteMensualDto) {
    return this.db.callFunctionJson<AuthSingleResult>('gad_reporte_mensual', [
      filtros.anio ?? null,
      filtros.mes ?? null,
    ]);
  }
}
