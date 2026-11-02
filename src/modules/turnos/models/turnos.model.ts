import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  ArqueoLineaDto,
  CerrarTurnoDto,
  CreateMovimientoDto,
  FiltroTurnosDto,
} from '../dto/turnos.dto';

@Injectable()
export class TurnosModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroTurnosDto, idSucursal: number) {
    return this.db.callFunctionJson<AuthListResult>('caj_listar_turnos', [
      filtros.limite ?? 10,
      filtros.offset ?? 0,
      filtros.id_caja ?? null,
      filtros.id_cajero ?? null,
      filtros.estado_turno ?? null,
      filtros.fecha_desde ?? null,
      filtros.fecha_hasta ?? null,
      idSucursal,
    ]);
  }

  obtenerPorId(id: number, idSucursal: number) {
    return this.db.callFunctionJson<AuthSingleResult>('caj_obtener_turno', [
      id,
      idSucursal,
    ]);
  }

  obtenerAbiertoPorCajero(idCajero: number, idSucursal: number) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'caj_obtener_turno_abierto',
      [idCajero, idSucursal],
    );
  }

  obtenerVigente(idUsuario: number, idSucursal: number | null) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'caj_obtener_turno_vigente',
      [idUsuario, idSucursal],
    );
  }

  /** Usuario con `es_super_admin` y sus roles activos (para autorizar el cierre). */
  obtenerUsuario(idUsuario: number) {
    return this.db.callFunctionJson<
      AuthSingleResult<{
        es_super_admin?: boolean;
        roles?: { codigo: string }[];
      }>
    >('auth_obtener_usuario', [idUsuario]);
  }

  resumen(id: number, idSucursal: number) {
    return this.db.callFunctionJson<AuthSingleResult>('caj_resumen_turno', [
      id,
      idSucursal,
    ]);
  }

  abrir(
    idCaja: number,
    idCajero: number,
    montoApertura: number,
    observacion: string | null,
    idUsuarioAuditoria: number | undefined,
    idSucursal: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('caj_abrir_turno', [
      idCaja,
      idCajero,
      montoApertura,
      observacion,
      idUsuarioAuditoria ?? null,
      idSucursal,
    ]);
  }

  cerrar(id: number, dto: CerrarTurnoDto, idSucursal: number) {
    return this.db.callFunctionJson<AuthSingleResult>('caj_cerrar_turno', [
      id,
      dto.monto_cierre_declarado,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
      idSucursal,
    ]);
  }

  registrarMovimiento(
    idTurno: number,
    dto: CreateMovimientoDto,
    idSucursal: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'caj_registrar_movimiento',
      [
        idTurno,
        dto.tipo_movimiento,
        dto.monto,
        dto.motivo,
        dto.id_usuario_autoriza ?? null,
        dto.idUsuarioAuditoria ?? null,
        idSucursal,
      ],
    );
  }

  listarMovimientos(idTurno: number, idSucursal: number) {
    return this.db.callFunctionJson<{ registros: unknown[]; resumen: unknown }>(
      'caj_listar_movimientos',
      [idTurno, idSucursal],
    );
  }

  anularMovimiento(
    id: number,
    idUsuarioAuditoria: number | undefined,
    idSucursal: number,
  ) {
    return this.db.callFunctionJson<AuthDeleteResult>('caj_anular_movimiento', [
      id,
      idUsuarioAuditoria ?? null,
      idSucursal,
    ]);
  }

  /**
   * El detalle del arqueo viaja como JSON en un solo parámetro.
   * Lo serializo acá porque `callFunctionJson` manda los parámetros tal cual y
   * la función SQL espera un tipo JSON, no un array de Postgres.
   */
  guardarArqueo(
    idTurno: number,
    detalle: ArqueoLineaDto[],
    idUsuarioAuditoria: number | undefined,
    idSucursal: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('caj_guardar_arqueo', [
      idTurno,
      JSON.stringify(detalle),
      idUsuarioAuditoria ?? null,
      idSucursal,
    ]);
  }
}
