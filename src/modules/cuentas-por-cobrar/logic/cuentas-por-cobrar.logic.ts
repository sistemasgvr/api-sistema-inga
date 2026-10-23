import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateAbonoCxcDto,
  CreateAjusteCxcDto,
  CreateConsumoDto,
  FiltroEstadoCuentaDetalleDto,
  FiltroEstadoCuentaDto,
  FiltroMovimientosCxcDto,
  FiltroReporteCxcDto,
  FiltroSaldosCxcDto,
} from '../dto/cuentas-por-cobrar.dto';
import { CuentasPorCobrarModel } from '../models/cuentas-por-cobrar.model';
import { NotificacionesLogic } from '../../notificaciones/logic/notificaciones.logic';
import { RutasNotificacion } from '../../notificaciones/constants/rutas-notificacion';

type MovimientoNotificado = {
  id?: number;
  id_persona?: number;
  nombre_persona?: string;
  monto?: number | string;
} | null;

const soles = (monto?: number | string) =>
  `S/ ${Number(monto ?? 0).toFixed(2)}`;

@Injectable()
export class CuentasPorCobrarLogic {
  constructor(
    private readonly model: CuentasPorCobrarModel,
    private readonly notificaciones: NotificacionesLogic,
  ) {}

  async listarSaldos(filtros: FiltroSaldosCxcDto) {
    const result = await this.model.listarSaldos(filtros);
    return mapListResult(result, filtros);
  }

  async listarMovimientos(filtros: FiltroMovimientosCxcDto) {
    const result = await this.model.listarMovimientos(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerMovimiento(id: number) {
    const result = await this.model.obtenerMovimiento(id);
    return mapSingleResult(result, `Movimiento con ID ${id} no encontrado`);
  }

  /**
   * Estado de cuenta para imprimir: saldo anterior, totales del rango, saldo al
   * cierre y cada movimiento con el pedido que lo originó y sus platos.
   */
  async obtenerEstadoCuentaDetalle(
    idPersona: number,
    filtros: FiltroEstadoCuentaDetalleDto,
  ) {
    const desde = filtros.fecha_desde?.slice(0, 10) ?? null;
    const hasta = filtros.fecha_hasta?.slice(0, 10) ?? null;
    if (desde && hasta && desde > hasta) {
      throw new BadRequestException(
        'La fecha inicial no puede ser posterior a la final',
      );
    }
    const resumen = await this.model.resumenEstadoCuentaDetalle(
      idPersona,
      desde,
      hasta,
    );
    if (!resumen) {
      throw new NotFoundException(
        `El cliente con ID ${idPersona} no existe o no está marcado como cliente`,
      );
    }
    const movimientos = await this.model.movimientosEstadoCuentaDetalle(
      idPersona,
      desde,
      hasta,
    );
    return {
      periodo: { fecha_desde: desde, fecha_hasta: hasta },
      ...resumen,
      movimientos,
    };
  }

  async obtenerEstadoCuenta(idPersona: number, filtros: FiltroEstadoCuentaDto) {
    const result = await this.model.obtenerEstadoCuenta(idPersona, filtros);
    return mapSingleResult(
      result,
      `El cliente con ID ${idPersona} no existe o no está marcado como cliente`,
    );
  }

  /**
   * Único caso del módulo donde no me basta con `mapSingleResult`.
   *
   * Decidí que pasarse del límite de crédito advierte pero no bloquea (el
   * motivo está escrito en cxc_registrar_consumo.sql). Esa advertencia viaja
   * como `supera_limite` al lado de `registro`, y `mapSingleResult` solo
   * devuelve `registro`, así que la perdería justo cuando más hace falta.
   * Por eso la vuelvo a pegar a mano sobre el registro.
   */
  async registrarConsumo(dto: CreateConsumoDto) {
    const result = await this.model.registrarConsumo(dto);
    const registro = mapSingleResult(result, 'No se pudo registrar el consumo');

    const movimiento = registro as MovimientoNotificado;
    this.notificaciones
      .emitir({
        canal: 'cuentas-por-cobrar',
        titulo: 'Consumo por cobrar registrado',
        // El nombre, no el ID: "Cliente 43" no le dice nada a la cajera.
        mensaje: movimiento?.nombre_persona
          ? `${movimiento.nombre_persona} · ${soles(movimiento.monto)}`
          : 'Se cargó un consumo a la cuenta de un cliente',
        severidad: 'info',
        ruta: RutasNotificacion.cuentaPorCobrar(movimiento?.id_persona),
        idReferencia: movimiento?.id ?? null,
      })
      ?.catch(() => undefined);

    return {
      ...(registro as Record<string, unknown>),
      supera_limite:
        (result as { supera_limite?: boolean }).supera_limite ?? false,
    };
  }

  async registrarAbono(dto: CreateAbonoCxcDto) {
    const result = await this.model.registrarAbono(dto);
    const registro = mapSingleResult(result, 'No se pudo registrar el abono');
    const movimiento = registro as MovimientoNotificado;
    this.notificaciones
      .emitir({
        canal: 'cuentas-por-cobrar',
        titulo: 'Abono a cuenta por cobrar',
        mensaje: movimiento?.nombre_persona
          ? `${movimiento.nombre_persona} · ${soles(movimiento.monto)}`
          : 'Movimiento registrado',
        severidad: 'success',
        ruta: RutasNotificacion.cuentaPorCobrar(movimiento?.id_persona),
        idReferencia: movimiento?.id ?? null,
      })
      ?.catch(() => undefined);
    return registro;
  }

  async registrarAjuste(dto: CreateAjusteCxcDto) {
    const result = await this.model.registrarAjuste(dto);
    return mapSingleResult(result, 'No se pudo registrar el ajuste');
  }

  /**
   * Uso `mapSingleResult` y no `mapDeleteResult` porque cxc_anular_movimiento
   * devuelve el movimiento ya anulado, no una bandera `eliminado`. Así el front
   * puede refrescar la fila con el dato real en vez de recargar la lista.
   */
  async anularMovimiento(
    id: number,
    motivo?: string,
    idUsuarioAuditoria?: number,
  ) {
    const result = await this.model.anularMovimiento(
      id,
      motivo,
      idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Movimiento con ID ${id} no encontrado`);
  }

  /**
   * El reporte siempre existe: si no hubo movimientos en la quincena, devuelve
   * el período con los totales en cero y la lista de empresas vacía. Por eso no
   * uso `mapSingleResult`, que lanzaría un 404 donde la respuesta correcta es
   * "no hubo consumos".
   */
  async reportePeriodo(filtros: FiltroReporteCxcDto) {
    const result = await this.model.reportePeriodo(filtros);

    if (result?.error) {
      throw new BadRequestException(result.error);
    }

    if (!result?.registro) {
      throw new NotFoundException('No se pudo generar el reporte del período');
    }

    return result.registro;
  }
}
