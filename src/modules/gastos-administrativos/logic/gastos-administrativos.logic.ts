import { Injectable, NotFoundException } from '@nestjs/common';
import {
  mapActivateResult,
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateCategoriaGastoDto,
  CreateGastoDto,
  FiltroCategoriasGastoDto,
  FiltroGastosDto,
  FiltroReporteMensualDto,
  UpdateCategoriaGastoDto,
  UpdateGastoDto,
} from '../dto/gastos-administrativos.dto';
import { GastosAdministrativosModel } from '../models/gastos-administrativos.model';

@Injectable()
export class GastosAdministrativosLogic {
  constructor(private readonly model: GastosAdministrativosModel) {}

  /* ------------------------------ Categorías ------------------------------ */

  /**
   * Devuelve el árbol completo, sin paginar.
   *
   * No uso `mapListResult` porque estas categorías no se paginan: son pocas
   * (las que el cliente configure) y el formulario de gasto necesita el árbol
   * entero para armar su selector agrupado.
   */
  async listarCategorias(filtros: FiltroCategoriasGastoDto) {
    return await this.model.listarCategorias(filtros);
  }

  async obtenerCategoria(id: number) {
    const result = await this.model.obtenerCategoria(id);
    return mapSingleResult(result, `Categoría con ID ${id} no encontrada`);
  }

  async crearCategoria(dto: CreateCategoriaGastoDto) {
    const result = await this.model.crearCategoria(dto);
    return mapSingleResult(result, 'No se pudo crear la categoría');
  }

  async actualizarCategoria(id: number, dto: UpdateCategoriaGastoDto) {
    const result = await this.model.actualizarCategoria(id, dto);
    return mapSingleResult(result, `Categoría con ID ${id} no encontrada`);
  }

  async eliminarCategoria(id: number, idUsuarioAuditoria?: number) {
    const result = await this.model.eliminarCategoria(id, idUsuarioAuditoria);
    return mapDeleteResult(
      result,
      `Categoría con ID ${id} no encontrada o ya inactiva`,
    );
  }

  async activarCategoria(id: number, idUsuarioAuditoria?: number) {
    const result = await this.model.activarCategoria(id, idUsuarioAuditoria);
    return mapActivateResult(
      result,
      `Categoría con ID ${id} no encontrada o ya activa`,
    );
  }

  /* -------------------------------- Gastos -------------------------------- */

  async listarGastos(filtros: FiltroGastosDto) {
    const result = await this.model.listarGastos(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerGasto(id: number) {
    const result = await this.model.obtenerGasto(id);
    return mapSingleResult(result, `Gasto con ID ${id} no encontrado`);
  }

  async registrarGasto(dto: CreateGastoDto) {
    const result = await this.model.registrarGasto(dto);
    return mapSingleResult(result, 'No se pudo registrar el gasto');
  }

  async actualizarGasto(id: number, dto: UpdateGastoDto) {
    const result = await this.model.actualizarGasto(id, dto);
    return mapSingleResult(result, `Gasto con ID ${id} no encontrado`);
  }

  async anularGasto(id: number, motivo?: string, idUsuarioAuditoria?: number) {
    const result = await this.model.anularGasto(id, motivo, idUsuarioAuditoria);
    return mapDeleteResult(result, `Gasto con ID ${id} no encontrado o ya anulado`);
  }

  /**
   * El reporte siempre existe: si no hubo gastos, devuelve el mes con los
   * totales en cero. Por eso no uso `mapSingleResult`, que lanzaría un 404
   * donde la respuesta correcta es "cero".
   */
  async reporteMensual(filtros: FiltroReporteMensualDto) {
    const result = await this.model.reporteMensual(filtros);

    if (!result?.registro) {
      throw new NotFoundException('No se pudo generar el reporte del mes');
    }

    return result.registro;
  }
}
