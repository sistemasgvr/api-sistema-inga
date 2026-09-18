import { Injectable, NotFoundException } from '@nestjs/common';
import {
  mapActivateResult,
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreatePagoDto,
  CreateTrabajadorDto,
  FiltroPagosDto,
  FiltroReportePeriodoDto,
  FiltroTrabajadoresDto,
  UpdateTrabajadorDto,
} from '../dto/planilla.dto';
import { PlanillaModel } from '../models/planilla.model';

/**
 * Orquesta las llamadas al modelo y traduce lo que devuelve la base en la
 * respuesta HTTP correcta.
 *
 * Los helpers `map*Result` convierten el `{ error: '...' }` de las funciones
 * SQL en un 400 o 404 real, así el mensaje escrito en el plpgsql llega tal cual
 * al usuario final.
 */
@Injectable()
export class PlanillaLogic {
  constructor(private readonly planillaModel: PlanillaModel) {}

  /* ---------------------------- Trabajadores ---------------------------- */

  async listarTrabajadores(filtros: FiltroTrabajadoresDto) {
    const result = await this.planillaModel.listarTrabajadores(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerTrabajador(id: number) {
    const result = await this.planillaModel.obtenerTrabajador(id);
    return mapSingleResult(result, `Trabajador con ID ${id} no encontrado`);
  }

  async crearTrabajador(dto: CreateTrabajadorDto) {
    const result = await this.planillaModel.crearTrabajador(dto);
    return mapSingleResult(result, 'No se pudo crear el trabajador');
  }

  async actualizarTrabajador(id: number, dto: UpdateTrabajadorDto) {
    const result = await this.planillaModel.actualizarTrabajador(id, dto);
    return mapSingleResult(result, `Trabajador con ID ${id} no encontrado`);
  }

  async eliminarTrabajador(id: number, idUsuarioAuditoria?: number) {
    const result = await this.planillaModel.eliminarTrabajador(id, idUsuarioAuditoria);
    return mapDeleteResult(
      result,
      `Trabajador con ID ${id} no encontrado o ya inactivo`,
    );
  }

  async activarTrabajador(id: number, idUsuarioAuditoria?: number) {
    const result = await this.planillaModel.activarTrabajador(id, idUsuarioAuditoria);
    return mapActivateResult(
      result,
      `Trabajador con ID ${id} no encontrado o ya activo`,
    );
  }

  /* -------------------------------- Pagos -------------------------------- */

  async listarPagos(filtros: FiltroPagosDto) {
    const result = await this.planillaModel.listarPagos(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPago(id: number) {
    const result = await this.planillaModel.obtenerPago(id);
    return mapSingleResult(result, `Pago con ID ${id} no encontrado`);
  }

  async registrarPago(dto: CreatePagoDto) {
    const result = await this.planillaModel.registrarPago(dto);
    return mapSingleResult(result, 'No se pudo registrar el pago');
  }

  async anularPago(id: number, motivo?: string, idUsuarioAuditoria?: number) {
    const result = await this.planillaModel.anularPago(id, motivo, idUsuarioAuditoria);
    return mapDeleteResult(result, `Pago con ID ${id} no encontrado o ya anulado`);
  }

  /**
   * El reporte siempre existe: si no hubo pagos, devuelve el período con los
   * totales en cero y la lista de pendientes. Por eso no uso `mapSingleResult`,
   * que lanzaría un 404 donde en realidad la respuesta correcta es "cero".
   */
  async reportePeriodo(filtros: FiltroReportePeriodoDto) {
    const result = await this.planillaModel.reportePeriodo(filtros);

    if (!result?.registro) {
      throw new NotFoundException('No se pudo generar el reporte del período');
    }

    return result.registro;
  }
}
