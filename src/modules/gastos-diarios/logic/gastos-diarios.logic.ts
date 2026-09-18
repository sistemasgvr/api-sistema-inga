import { Injectable, NotFoundException } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  AbrirDiaDto,
  CreateInsumoDto,
  CreateLineaDto,
  FiltroDiasDto,
  FiltroInsumosDto,
  FiltroReporteDiaDto,
  UpdateInsumoDto,
} from '../dto/gastos-diarios.dto';
import { GastosDiariosModel } from '../models/gastos-diarios.model';

@Injectable()
export class GastosDiariosLogic {
  constructor(private readonly model: GastosDiariosModel) {}

  /* -------------------------------- Insumos -------------------------------- */

  /**
   * Devuelve el árbol completo de categorías con sus insumos, sin paginar.
   *
   * No uso `mapListResult` porque no es un listado paginado: el formulario de
   * registro rápido necesita la lista entera a mano para buscar sin ir al
   * servidor en cada tecla.
   */
  async listarInsumos(filtros: FiltroInsumosDto) {
    return await this.model.listarInsumos(filtros);
  }

  async obtenerInsumo(id: number) {
    const result = await this.model.obtenerInsumo(id);
    return mapSingleResult(result, `Insumo con ID ${id} no encontrado`);
  }

  async crearInsumo(dto: CreateInsumoDto) {
    const result = await this.model.crearInsumo(dto);
    return mapSingleResult(result, 'No se pudo crear el insumo');
  }

  async actualizarInsumo(id: number, dto: UpdateInsumoDto) {
    const result = await this.model.actualizarInsumo(id, dto);
    return mapSingleResult(result, `Insumo con ID ${id} no encontrado`);
  }

  async toggleInsumo(id: number, idUsuarioAuditoria?: number) {
    const result = await this.model.toggleInsumo(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Insumo con ID ${id} no encontrado`);
  }

  /* ------------------------------ Gasto del día ---------------------------- */

  async abrirDia(dto: AbrirDiaDto) {
    const result = await this.model.abrirDia(dto);
    return mapSingleResult(result, 'No se pudo abrir el gasto del día');
  }

  async obtenerDia(id: number) {
    const result = await this.model.obtenerDia(id);
    return mapSingleResult(result, `Gasto del día con ID ${id} no encontrado`);
  }

  async listarDias(filtros: FiltroDiasDto) {
    const result = await this.model.listarDias(filtros);
    return mapListResult(result, filtros);
  }

  async agregarLinea(idGastoDia: number, dto: CreateLineaDto) {
    const result = await this.model.agregarLinea(idGastoDia, dto);
    return mapSingleResult(result, 'No se pudo agregar la compra');
  }

  async anularLinea(id: number, motivo?: string, idUsuarioAuditoria?: number) {
    const result = await this.model.anularLinea(id, motivo, idUsuarioAuditoria);
    return mapSingleResult(result, `Línea con ID ${id} no encontrada`);
  }

  /**
   * El reporte siempre existe: un día sin compras devuelve todo en cero, que es
   * una respuesta válida. Por eso no uso `mapSingleResult`, que lanzaría un 404.
   */
  async reporteDia(filtros: FiltroReporteDiaDto) {
    const result = await this.model.reporteDia(filtros);

    if (!result?.registro) {
      throw new NotFoundException('No se pudo generar el reporte del día');
    }

    return result.registro;
  }
}
