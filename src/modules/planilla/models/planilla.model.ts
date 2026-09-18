import { Injectable } from '@nestjs/common';
import {
  AuthActivateResult,
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  CreatePagoDto,
  CreateTrabajadorDto,
  FiltroPagosDto,
  FiltroReportePeriodoDto,
  FiltroTrabajadoresDto,
  TrabajadorEstadoFiltro,
  UpdateTrabajadorDto,
} from '../dto/planilla.dto';

/**
 * Capa que habla con la base. No decide nada: solo traduce los datos que
 * recibe a los parámetros que espera cada función SQL, en el orden correcto.
 * Toda la regla de negocio vive en las funciones `pla_*`.
 */
@Injectable()
export class PlanillaModel {
  constructor(private readonly db: DatabaseService) {}

  private resolveEstadoFiltro(estado?: TrabajadorEstadoFiltro): number | null {
    if (estado === 'inactivos') return 0;
    if (estado === 'todos') return null;
    return 1;
  }

  /* ---------------------------- Trabajadores ---------------------------- */

  listarTrabajadores(filtros: FiltroTrabajadoresDto) {
    return this.db.callFunctionJson<AuthListResult>('pla_listar_trabajadores', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset ?? 0,
      filtros.anio ?? null,
      filtros.mes ?? null,
      filtros.quincena ?? null,
      this.resolveEstadoFiltro(filtros.estado),
    ]);
  }

  obtenerTrabajador(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('pla_obtener_trabajador', [id]);
  }

  crearTrabajador(dto: CreateTrabajadorDto) {
    return this.db.callFunctionJson<AuthSingleResult>('pla_crear_trabajador', [
      dto.nombres,
      dto.apellidos,
      dto.num_documento ?? null,
      dto.puesto ?? null,
      dto.sueldo_referencial ?? 0,
      dto.id_sucursal ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  actualizarTrabajador(id: number, dto: UpdateTrabajadorDto) {
    return this.db.callFunctionJson<AuthSingleResult>('pla_actualizar_trabajador', [
      id,
      dto.nombres ?? null,
      dto.apellidos ?? null,
      dto.num_documento ?? null,
      dto.puesto ?? null,
      // `?? null` y no `|| null`: un sueldo de 0 es válido y con `||` se
      // convertiría en null, dejando el valor anterior sin cambiar.
      dto.sueldo_referencial ?? null,
      dto.id_sucursal ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  eliminarTrabajador(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('pla_eliminar_trabajador', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  activarTrabajador(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthActivateResult>('pla_activar_trabajador', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  /* -------------------------------- Pagos -------------------------------- */

  listarPagos(filtros: FiltroPagosDto) {
    return this.db.callFunctionJson<AuthListResult>('pla_listar_pagos', [
      filtros.limite ?? 10,
      filtros.offset ?? 0,
      filtros.id_trabajador ?? null,
      filtros.anio ?? null,
      filtros.mes ?? null,
      filtros.quincena ?? null,
      filtros.medio_pago ?? null,
      filtros.fecha_desde ?? null,
      filtros.fecha_hasta ?? null,
    ]);
  }

  obtenerPago(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('pla_obtener_pago', [id]);
  }

  registrarPago(dto: CreatePagoDto) {
    return this.db.callFunctionJson<AuthSingleResult>('pla_registrar_pago', [
      dto.id_trabajador,
      dto.monto,
      dto.fecha_pago ?? null,
      dto.medio_pago ?? 1,
      dto.id_turno ?? null,
      dto.anio ?? null,
      dto.mes ?? null,
      dto.quincena ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  anularPago(id: number, motivo?: string, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('pla_anular_pago', [
      id,
      motivo ?? null,
      idUsuarioAuditoria ?? null,
    ]);
  }

  reportePeriodo(filtros: FiltroReportePeriodoDto) {
    return this.db.callFunctionJson<AuthSingleResult>('pla_reporte_periodo', [
      filtros.anio ?? null,
      filtros.mes ?? null,
      filtros.quincena ?? null,
    ]);
  }
}
