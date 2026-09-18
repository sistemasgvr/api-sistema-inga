import { Injectable } from '@nestjs/common';
import {
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  CreateAbonoCxcDto,
  CreateAjusteCxcDto,
  CreateConsumoDto,
  FiltroEstadoCuentaDto,
  FiltroMovimientosCxcDto,
  FiltroReporteCxcDto,
  FiltroSaldosCxcDto,
} from '../dto/cuentas-por-cobrar.dto';

/**
 * Capa que habla con la base. No decide nada: traduce los datos a los
 * parámetros que espera cada función SQL, en el orden correcto.
 * Toda la regla de negocio vive en las funciones `cxc_*`.
 */
@Injectable()
export class CuentasPorCobrarModel {
  constructor(private readonly db: DatabaseService) {}

  listarSaldos(filtros: FiltroSaldosCxcDto) {
    return this.db.callFunctionJson<AuthListResult>('cxc_listar_saldos', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset ?? 0,
      filtros.solo_con_deuda ?? false,
      filtros.id_convenio ?? null,
    ]);
  }

  listarMovimientos(filtros: FiltroMovimientosCxcDto) {
    return this.db.callFunctionJson<AuthListResult>('cxc_listar_movimientos', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset ?? 0,
      filtros.id_persona ?? null,
      filtros.id_convenio ?? null,
      filtros.tipo_movimiento ?? null,
      filtros.anio ?? null,
      filtros.mes ?? null,
      filtros.quincena ?? null,
      filtros.incluir_anulados ?? false,
    ]);
  }

  obtenerMovimiento(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('cxc_obtener_movimiento', [id]);
  }

  obtenerEstadoCuenta(idPersona: number, filtros: FiltroEstadoCuentaDto) {
    return this.db.callFunctionJson<AuthSingleResult>('cxc_obtener_estado_cuenta', [
      idPersona,
      filtros.anio ?? null,
      filtros.mes ?? null,
      filtros.quincena ?? null,
    ]);
  }

  registrarConsumo(dto: CreateConsumoDto) {
    return this.db.callFunctionJson<AuthSingleResult>('cxc_registrar_consumo', [
      dto.id_persona,
      dto.monto,
      dto.fecha_movimiento ?? null,
      dto.id_pedido ?? null,
      dto.id_pago ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  registrarAbono(dto: CreateAbonoCxcDto) {
    return this.db.callFunctionJson<AuthSingleResult>('cxc_registrar_abono', [
      dto.id_persona,
      dto.monto,
      dto.fecha_movimiento ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  registrarAjuste(dto: CreateAjusteCxcDto) {
    return this.db.callFunctionJson<AuthSingleResult>('cxc_registrar_ajuste', [
      dto.id_persona,
      dto.monto,
      dto.motivo,
      dto.fecha_movimiento ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  // Devuelve AuthSingleResult y no AuthDeleteResult porque cxc_anular_movimiento
  // responde con el movimiento ya anulado, no con una bandera `eliminado`.
  anularMovimiento(id: number, motivo?: string, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthSingleResult>('cxc_anular_movimiento', [
      id,
      motivo ?? null,
      idUsuarioAuditoria ?? null,
    ]);
  }

  reportePeriodo(filtros: FiltroReporteCxcDto) {
    return this.db.callFunctionJson<AuthSingleResult>('cxc_reporte_periodo', [
      filtros.anio ?? null,
      filtros.mes ?? null,
      filtros.quincena ?? null,
      filtros.id_convenio ?? null,
    ]);
  }
}
