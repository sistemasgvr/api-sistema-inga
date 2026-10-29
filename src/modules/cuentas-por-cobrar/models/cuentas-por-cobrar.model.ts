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

// Día de Lima del movimiento; el filtro usa el mismo criterio que el listado.
const DIA_MOV = `(m.fecha_creacion AT TIME ZONE 'America/Lima')::DATE`;

// Ajuste (3) entra con su signo, igual que en cxc_obtener_estado_cuenta.
const MONTO_CON_SIGNO = `CASE m.tipo_movimiento WHEN 1 THEN m.monto WHEN 2 THEN -m.monto ELSE m.monto END`;

const SQL_DETALLE_RESUMEN = `
  SELECT v.id_persona::INT AS id_persona, v.nombre, v.num_documento, v.convenio,
    v.limite_credito::FLOAT8 AS limite_credito, COALESCE(v.saldo, 0)::FLOAT8 AS saldo_actual,
    COALESCE(sum(${MONTO_CON_SIGNO}) FILTER (WHERE $2::DATE IS NOT NULL AND ${DIA_MOV} < $2::DATE), 0)::FLOAT8 AS saldo_anterior,
    COALESCE(sum(m.monto) FILTER (WHERE m.tipo_movimiento = 1 AND ${DIA_MOV} BETWEEN COALESCE($2::DATE, '-infinity') AND COALESCE($3::DATE, 'infinity')), 0)::FLOAT8 AS total_cargos,
    COALESCE(sum(m.monto) FILTER (WHERE m.tipo_movimiento = 2 AND ${DIA_MOV} BETWEEN COALESCE($2::DATE, '-infinity') AND COALESCE($3::DATE, 'infinity')), 0)::FLOAT8 AS total_abonos,
    COALESCE(sum(m.monto) FILTER (WHERE m.tipo_movimiento = 3 AND ${DIA_MOV} BETWEEN COALESCE($2::DATE, '-infinity') AND COALESCE($3::DATE, 'infinity')), 0)::FLOAT8 AS total_ajustes,
    COALESCE(sum(${MONTO_CON_SIGNO}) FILTER (WHERE $3::DATE IS NULL OR ${DIA_MOV} <= $3::DATE), 0)::FLOAT8 AS saldo_final
  FROM vw_cxc_saldo_persona v
  LEFT JOIN cxc_movimiento m ON m.id_persona = v.id_persona AND m.estado = 1
  WHERE v.id_persona = $1
  GROUP BY v.id_persona, v.nombre, v.num_documento, v.convenio, v.limite_credito, v.saldo`;

const SQL_DETALLE_MOVIMIENTOS = `
  WITH medios AS (
    SELECT o.valor_entero AS medio_pago, o.nombre
    FROM gen_lista_opcion o JOIN gen_lista l ON l.id = o.id_lista
    WHERE l.codigo = 'MEDIO_PAGO'
  )
  SELECT m.id::INT AS id, m.tipo_movimiento::INT AS tipo_movimiento,
    to_char(m.fecha_creacion AT TIME ZONE 'America/Lima', 'YYYY-MM-DD HH24:MI') AS fecha,
    m.monto::FLOAT8 AS monto, m.anio::INT AS anio, m.mes::INT AS mes, m.quincena::INT AS quincena,
    m.medio_pago::INT AS medio_pago, mp.nombre AS medio_pago_nombre, m.observacion,
    CASE WHEN p.id IS NULL THEN NULL ELSE json_build_object(
      'id', p.id,
      'codigo', p.codigo,
      'tipo_pedido', p.tipo_pedido,
      'fecha', to_char(COALESCE(p.fecha_cierre, p.fecha_apertura) AT TIME ZONE 'America/Lima', 'YYYY-MM-DD HH24:MI'),
      'mesa', (SELECT me.codigo FROM ven_mesa me WHERE me.id = p.id_mesa),
      'mozo', (SELECT COALESCE(NULLIF(trim(concat_ws(' ', u.nombres, u.apellidos)), ''), u.username)
               FROM auth_usuario_datos u WHERE u.id = p.id_mozo),
      'comensales', p.num_comensales,
      'total', p.monto_total::FLOAT8,
      'comprobante', (SELECT c.serie || '-' || c.correlativo FROM ven_comprobante c
                      WHERE c.id_pedido = p.id AND c.estado = 1 ORDER BY c.id DESC LIMIT 1),
      'pagos', COALESCE((SELECT json_agg(json_build_object('medio', COALESCE(md.nombre, g.medio_pago::TEXT), 'monto', g.monto::FLOAT8) ORDER BY g.id)
                         FROM ven_pago g LEFT JOIN medios md ON md.medio_pago = g.medio_pago
                         WHERE g.id_pedido = p.id AND g.estado = 1), '[]'::JSON),
      'lineas', COALESCE((SELECT json_agg(json_build_object(
                  'id', d.id,
                  'producto', pr.nombre,
                  'cantidad', (d.cantidad - d.cantidad_cancelada)::FLOAT8,
                  'precio_unitario', d.precio_unitario::FLOAT8,
                  'adicionales', COALESCE((SELECT json_agg(json_build_object('nombre', a.nombre, 'precio', da.precio_adicional::FLOAT8) ORDER BY da.id)
                                           FROM ven_pedido_detalle_adicional da JOIN pro_adicional a ON a.id = da.id_adicional
                                           WHERE da.id_pedido_detalle = d.id AND da.estado = 1), '[]'::JSON),
                  'descuento', d.monto_descuento::FLOAT8,
                  'subtotal', d.monto_subtotal::FLOAT8,
                  'cortesia', d.tipo_linea = 2) ORDER BY d.id)
                FROM ven_pedido_detalle d JOIN pro_producto pr ON pr.id = d.id_producto
                WHERE d.id_pedido = p.id AND d.estado = 1 AND d.tipo_linea <> 3
                  AND d.cantidad > d.cantidad_cancelada), '[]'::JSON)
    ) END AS pedido
  FROM cxc_movimiento m
  LEFT JOIN ven_pedido p ON p.id = m.id_pedido
  LEFT JOIN medios mp ON mp.medio_pago = m.medio_pago
  WHERE m.id_persona = $1 AND m.estado = 1
    AND ($2::DATE IS NULL OR ${DIA_MOV} >= $2::DATE)
    AND ($3::DATE IS NULL OR ${DIA_MOV} <= $3::DATE)
  ORDER BY m.fecha_creacion, m.id`;

/**
 * Capa que habla con la base. No decide nada: traduce los datos a los
 * parámetros que espera cada función SQL, en el orden correcto.
 * Toda la regla de negocio vive en las funciones `cxc_*`.
 */
@Injectable()
export class CuentasPorCobrarModel {
  constructor(private readonly db: DatabaseService) {}

  listarSaldos(filtros: FiltroSaldosCxcDto, idEmpresa?: number | null) {
    return this.db.callFunctionJson<AuthListResult>('cxc_listar_saldos', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset ?? 0,
      filtros.solo_con_deuda ?? false,
      filtros.id_convenio ?? null,
      idEmpresa ?? null,
    ]);
  }

  listarMovimientos(
    filtros: FiltroMovimientosCxcDto,
    idEmpresa?: number | null,
  ) {
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
      idEmpresa ?? null,
    ]);
  }

  obtenerMovimiento(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'cxc_obtener_movimiento',
      [id],
    );
  }

  obtenerEstadoCuenta(idPersona: number, filtros: FiltroEstadoCuentaDto) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'cxc_obtener_estado_cuenta',
      [
        idPersona,
        filtros.anio ?? null,
        filtros.mes ?? null,
        filtros.quincena ?? null,
      ],
    );
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
      dto.id_pedido ?? null,
      dto.medio_pago,
      dto.id_turno ?? null,
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

  /* ------------------- Estado de cuenta detallado ------------------- */
  //
  // Solo lectura, para imprimir o exportar. Va como consulta parametrizada
  // (no como función cxc_*) porque no decide nada: junta los movimientos con
  // el pedido que originó cada cargo y sus platos. Parámetros comunes:
  // $1 id_persona, $2 desde y $3 hasta (DATE de Lima, NULL = sin límite).

  async resumenEstadoCuentaDetalle(
    idPersona: number,
    desde: string | null,
    hasta: string | null,
  ) {
    const { rows } = await this.db.query(SQL_DETALLE_RESUMEN, [
      idPersona,
      desde,
      hasta,
    ]);
    return rows[0] ?? null;
  }

  async movimientosEstadoCuentaDetalle(
    idPersona: number,
    desde: string | null,
    hasta: string | null,
  ) {
    const { rows } = await this.db.query(SQL_DETALLE_MOVIMIENTOS, [
      idPersona,
      desde,
      hasta,
    ]);
    return rows;
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
