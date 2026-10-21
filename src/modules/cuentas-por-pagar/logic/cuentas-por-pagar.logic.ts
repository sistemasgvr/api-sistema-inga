import { Injectable, NotFoundException } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateAbonoDto,
  CreateAjusteDto,
  CreateCargoDto,
  FiltroMovimientosCxpDto,
  FiltroReporteCxpDto,
  FiltroSaldosDto,
} from '../dto/cuentas-por-pagar.dto';
import { CuentasPorPagarModel } from '../models/cuentas-por-pagar.model';
import { NotificacionesLogic } from '../../notificaciones/logic/notificaciones.logic';

@Injectable()
export class CuentasPorPagarLogic {
  constructor(
    private readonly model: CuentasPorPagarModel,
    private readonly notificaciones: NotificacionesLogic,
  ) {}

  async listarSaldos(filtros: FiltroSaldosDto) {
    const result = await this.model.listarSaldos(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerEstadoCuenta(idPersona: number, limiteMovimientos?: number) {
    const result = await this.model.obtenerEstadoCuenta(
      idPersona,
      limiteMovimientos,
    );

    if (!result?.registro) {
      throw new NotFoundException(
        `El proveedor con ID ${idPersona} no existe o no está marcado como proveedor`,
      );
    }

    return result.registro;
  }

  async listarMovimientos(filtros: FiltroMovimientosCxpDto) {
    const result = await this.model.listarMovimientos(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerMovimiento(id: number) {
    const result = await this.model.obtenerMovimiento(id);
    return mapSingleResult(result, `Movimiento con ID ${id} no encontrado`);
  }

  async registrarCargo(dto: CreateCargoDto) {
    const result = await this.model.registrarCargo(dto);
    const registro = mapSingleResult(result, 'No se pudo registrar el cargo');
    this.notificaciones.emitir({
      canal: 'cuentas-por-pagar' as any,
      titulo: 'Cargo por pagar registrado',
      mensaje:
        (registro as { nombre_proveedor?: string })?.nombre_proveedor ??
        'Se cargó una compra a la cuenta de un proveedor',
      severidad: 'info',
      ruta: '/cuentas-por-pagar',
      idReferencia: (registro as { id?: number })?.id ?? null,
    })?.catch(() => undefined);
    return registro;
  }

  async registrarAbono(dto: CreateAbonoDto) {
    const result = await this.model.registrarAbono(dto);
    const registro = mapSingleResult(result, 'No se pudo registrar el abono');
    this.notificaciones.emitir({
      canal: 'cuentas-por-pagar' as any,
      titulo: 'Abono a cuenta por pagar',
      mensaje: `Movimiento registrado`,
      severidad: 'success',
      ruta: '/cuentas-por-pagar',
      idReferencia: (registro as { id?: number })?.id ?? null,
    })?.catch(() => undefined);
    return registro;
  }

  async registrarAjuste(dto: CreateAjusteDto) {
    const result = await this.model.registrarAjuste(dto);
    return mapSingleResult(result, 'No se pudo registrar el ajuste');
  }

  async anularMovimiento(id: number, motivo?: string, idUsuarioAuditoria?: number) {
    const result = await this.model.anularMovimiento(id, motivo, idUsuarioAuditoria);
    return mapDeleteResult(
      result,
      `Movimiento con ID ${id} no encontrado o ya anulado`,
    );
  }

  /**
   * El reporte siempre existe: si no hubo movimientos, devuelve el período con
   * los totales en cero. Por eso no uso `mapSingleResult`, que lanzaría un 404
   * donde la respuesta correcta es "cero".
   */
  async reportePeriodo(filtros: FiltroReporteCxpDto) {
    const result = await this.model.reportePeriodo(filtros);

    if (!result?.registro) {
      throw new NotFoundException('No se pudo generar el reporte del período');
    }

    return result.registro;
  }
}
