import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import {
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateAbonoCxcDto,
  CreateAjusteCxcDto,
  CreateConsumoDto,
  FiltroEstadoCuentaDto,
  FiltroMovimientosCxcDto,
  FiltroReporteCxcDto,
  FiltroSaldosCxcDto,
} from '../dto/cuentas-por-cobrar.dto';
import { CuentasPorCobrarModel } from '../models/cuentas-por-cobrar.model';

@Injectable()
export class CuentasPorCobrarLogic {
  constructor(private readonly model: CuentasPorCobrarModel) {}

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

    return {
      ...(registro as Record<string, unknown>),
      supera_limite: (result as { supera_limite?: boolean }).supera_limite ?? false,
    };
  }

  async registrarAbono(dto: CreateAbonoCxcDto) {
    const result = await this.model.registrarAbono(dto);
    return mapSingleResult(result, 'No se pudo registrar el abono');
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
  async anularMovimiento(id: number, motivo?: string, idUsuarioAuditoria?: number) {
    const result = await this.model.anularMovimiento(id, motivo, idUsuarioAuditoria);
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
