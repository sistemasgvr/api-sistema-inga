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
import { RutasNotificacion } from '../../notificaciones/constants/rutas-notificacion';

type MovimientoNotificado = {
  id?: number;
  id_persona?: number;
  nombre_proveedor?: string;
  monto?: number | string;
} | null;

const soles = (monto?: number | string) =>
  `S/ ${Number(monto ?? 0).toFixed(2)}`;

@Injectable()
export class CuentasPorPagarLogic {
  constructor(
    private readonly model: CuentasPorPagarModel,
    private readonly notificaciones: NotificacionesLogic,
  ) {}

  async listarSaldos(filtros: FiltroSaldosDto, idEmpresa?: number | null) {
    const result = await this.model.listarSaldos(filtros, idEmpresa);
    return mapListResult(result, filtros);
  }

  async obtenerEstadoCuenta(
    idPersona: number,
    limiteMovimientos?: number,
    idEmpresa?: number | null,
  ) {
    const result = await this.model.obtenerEstadoCuenta(
      idPersona,
      limiteMovimientos,
      idEmpresa,
    );

    if (!result?.registro) {
      throw new NotFoundException(
        `El proveedor con ID ${idPersona} no existe o no está marcado como proveedor`,
      );
    }

    return result.registro;
  }

  async listarMovimientos(
    filtros: FiltroMovimientosCxpDto,
    idEmpresa?: number | null,
  ) {
    const result = await this.model.listarMovimientos(filtros, idEmpresa);
    return mapListResult(result, filtros);
  }

  async obtenerMovimiento(id: number, idEmpresa?: number | null) {
    const result = await this.model.obtenerMovimiento(id, idEmpresa);
    return mapSingleResult(result, `Movimiento con ID ${id} no encontrado`);
  }

  async registrarCargo(dto: CreateCargoDto, idEmpresa?: number | null) {
    const result = await this.model.registrarCargo(dto, idEmpresa);
    const registro = mapSingleResult(result, 'No se pudo registrar el cargo');
    const movimiento = registro as MovimientoNotificado;
    this.notificaciones
      .emitir({
        canal: 'cuentas-por-pagar',
        titulo: 'Cargo por pagar registrado',
        mensaje: movimiento?.nombre_proveedor
          ? `${movimiento.nombre_proveedor} · ${soles(movimiento.monto)}`
          : 'Se cargó una compra a la cuenta de un proveedor',
        severidad: 'info',
        ruta: RutasNotificacion.cuentaPorPagar(movimiento?.id_persona),
        idReferencia: movimiento?.id ?? null,
        idEmpresa,
      })
      ?.catch(() => undefined);
    return registro;
  }

  async registrarAbono(dto: CreateAbonoDto, idEmpresa?: number | null) {
    const result = await this.model.registrarAbono(dto, idEmpresa);
    const registro = mapSingleResult(result, 'No se pudo registrar el abono');
    const movimiento = registro as MovimientoNotificado;
    this.notificaciones
      .emitir({
        canal: 'cuentas-por-pagar',
        titulo: 'Abono a cuenta por pagar',
        mensaje: movimiento?.nombre_proveedor
          ? `${movimiento.nombre_proveedor} · ${soles(movimiento.monto)}`
          : 'Movimiento registrado',
        severidad: 'success',
        ruta: RutasNotificacion.cuentaPorPagar(movimiento?.id_persona),
        idReferencia: movimiento?.id ?? null,
        idEmpresa,
      })
      ?.catch(() => undefined);
    return registro;
  }

  async registrarAjuste(dto: CreateAjusteDto, idEmpresa?: number | null) {
    const result = await this.model.registrarAjuste(dto, idEmpresa);
    return mapSingleResult(result, 'No se pudo registrar el ajuste');
  }

  async anularMovimiento(
    id: number,
    motivo?: string,
    idUsuarioAuditoria?: number,
    idEmpresa?: number | null,
  ) {
    const result = await this.model.anularMovimiento(
      id,
      motivo,
      idUsuarioAuditoria,
      idEmpresa,
    );
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
  async reportePeriodo(
    filtros: FiltroReporteCxpDto,
    idEmpresa?: number | null,
  ) {
    const result = await this.model.reportePeriodo(filtros, idEmpresa);

    if (!result?.registro) {
      throw new NotFoundException('No se pudo generar el reporte del período');
    }

    return result.registro;
  }
}
