import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  CreateAbonoDto,
  CreateAjusteDto,
  CreateCargoDto,
  FiltroMovimientosCxpDto,
  FiltroReporteCxpDto,
  FiltroSaldosDto,
} from '../dto/cuentas-por-pagar.dto';

/**
 * Capa que habla con la base. No decide nada: traduce los datos a los
 * parámetros que espera cada función SQL, en el orden correcto.
 * Toda la regla de negocio vive en las funciones `cxp_*`.
 */
@Injectable()
export class CuentasPorPagarModel {
  constructor(private readonly db: DatabaseService) {}

  listarSaldos(filtros: FiltroSaldosDto) {
    return this.db.callFunctionJson<AuthListResult>('cxp_listar_saldos', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset ?? 0,
      filtros.solo_con_deuda ?? false,
    ]);
  }

  obtenerEstadoCuenta(idPersona: number, limiteMovimientos = 20) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'cxp_obtener_estado_cuenta',
      [idPersona, limiteMovimientos],
    );
  }

  listarMovimientos(filtros: FiltroMovimientosCxpDto) {
    return this.db.callFunctionJson<AuthListResult>('cxp_listar_movimientos', [
      filtros.limite ?? 10,
      filtros.offset ?? 0,
      filtros.id_persona ?? null,
      filtros.tipo_movimiento ?? null,
      filtros.anio ?? null,
      filtros.mes ?? null,
      filtros.semana ?? null,
      filtros.fecha_desde ?? null,
      filtros.fecha_hasta ?? null,
    ]);
  }

  obtenerMovimiento(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('cxp_obtener_movimiento', [id]);
  }

  registrarCargo(dto: CreateCargoDto) {
    return this.db.callFunctionJson<AuthSingleResult>('cxp_registrar_cargo', [
      dto.id_persona,
      dto.monto,
      dto.fecha_movimiento ?? null,
      dto.num_comprobante ?? null,
      dto.id_gasto_diario ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  registrarAbono(dto: CreateAbonoDto) {
    return this.db.callFunctionJson<AuthSingleResult>('cxp_registrar_abono', [
      dto.id_persona,
      dto.monto,
      dto.medio_pago ?? 1,
      dto.id_turno ?? null,
      dto.fecha_movimiento ?? null,
      dto.num_comprobante ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  registrarAjuste(dto: CreateAjusteDto) {
    return this.db.callFunctionJson<AuthSingleResult>('cxp_registrar_ajuste', [
      dto.id_persona,
      dto.monto,
      dto.motivo,
      dto.fecha_movimiento ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  anularMovimiento(id: number, motivo?: string, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('cxp_anular_movimiento', [
      id,
      motivo ?? null,
      idUsuarioAuditoria ?? null,
    ]);
  }

  reportePeriodo(filtros: FiltroReporteCxpDto) {
    return this.db.callFunctionJson<AuthSingleResult>('cxp_reporte_periodo', [
      filtros.anio ?? null,
      filtros.mes ?? null,
    ]);
  }
}
