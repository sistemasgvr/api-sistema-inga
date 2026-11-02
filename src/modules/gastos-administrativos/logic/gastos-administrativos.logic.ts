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
import { NotificacionesLogic } from '../../notificaciones/logic/notificaciones.logic';
import { RutasNotificacion } from '../../notificaciones/constants/rutas-notificacion';

@Injectable()
export class GastosAdministrativosLogic {
  constructor(
    private readonly model: GastosAdministrativosModel,
    private readonly notificaciones: NotificacionesLogic,
  ) {}

  /* ------------------------------ Categorías ------------------------------ */

  /**
   * Devuelve el árbol completo, sin paginar.
   *
   * No uso `mapListResult` porque estas categorías no se paginan: son pocas
   * (las que el cliente configure) y el formulario de gasto necesita el árbol
   * entero para armar su selector agrupado.
   */
  async listarCategorias(
    filtros: FiltroCategoriasGastoDto,
    idEmpresa?: number | null,
  ) {
    return await this.model.listarCategorias(filtros, idEmpresa);
  }

  async obtenerCategoria(id: number, idEmpresa?: number | null) {
    const result = await this.model.obtenerCategoria(id, idEmpresa);
    return mapSingleResult(result, `Categoría con ID ${id} no encontrada`);
  }

  async crearCategoria(
    dto: CreateCategoriaGastoDto,
    idEmpresa?: number | null,
  ) {
    const result = await this.model.crearCategoria(dto, idEmpresa);
    return mapSingleResult(result, 'No se pudo crear la categoría');
  }

  async actualizarCategoria(
    id: number,
    dto: UpdateCategoriaGastoDto,
    idEmpresa?: number | null,
  ) {
    const result = await this.model.actualizarCategoria(id, dto, idEmpresa);
    return mapSingleResult(result, `Categoría con ID ${id} no encontrada`);
  }

  async eliminarCategoria(
    id: number,
    idUsuarioAuditoria?: number,
    idEmpresa?: number | null,
  ) {
    const result = await this.model.eliminarCategoria(
      id,
      idUsuarioAuditoria,
      idEmpresa,
    );
    return mapDeleteResult(
      result,
      `Categoría con ID ${id} no encontrada o ya inactiva`,
    );
  }

  async activarCategoria(
    id: number,
    idUsuarioAuditoria?: number,
    idEmpresa?: number | null,
  ) {
    const result = await this.model.activarCategoria(
      id,
      idUsuarioAuditoria,
      idEmpresa,
    );
    return mapActivateResult(
      result,
      `Categoría con ID ${id} no encontrada o ya activa`,
    );
  }

  /* -------------------------------- Gastos -------------------------------- */

  async listarGastos(filtros: FiltroGastosDto, idEmpresa?: number | null) {
    const result = await this.model.listarGastos(filtros, idEmpresa);
    return mapListResult(result, filtros);
  }

  async obtenerGasto(id: number, idEmpresa?: number | null) {
    const result = await this.model.obtenerGasto(id, idEmpresa);
    return mapSingleResult(result, `Gasto con ID ${id} no encontrado`);
  }

  async registrarGasto(dto: CreateGastoDto, idEmpresa?: number | null) {
    const result = await this.model.registrarGasto(dto, idEmpresa);
    const registro = mapSingleResult(result, 'No se pudo registrar el gasto');
    const gasto = registro as {
      id?: number;
      concepto?: string;
      monto?: number | string;
    } | null;
    this.notificaciones
      .emitir({
        canal: 'gastos',
        titulo: 'Gasto administrativo registrado',
        mensaje: gasto?.concepto
          ? `${gasto.concepto} · S/ ${Number(gasto.monto ?? 0).toFixed(2)}`
          : 'Gasto registrado',
        severidad: 'info',
        ruta: RutasNotificacion.gastos(),
        idReferencia: gasto?.id ?? null,
        idEmpresa,
      })
      ?.catch(() => undefined);
    return registro;
  }

  async actualizarGasto(
    id: number,
    dto: UpdateGastoDto,
    idEmpresa?: number | null,
  ) {
    const result = await this.model.actualizarGasto(id, dto, idEmpresa);
    return mapSingleResult(result, `Gasto con ID ${id} no encontrado`);
  }

  async anularGasto(
    id: number,
    motivo?: string,
    idUsuarioAuditoria?: number,
    idEmpresa?: number | null,
  ) {
    const result = await this.model.anularGasto(
      id,
      motivo,
      idUsuarioAuditoria,
      idEmpresa,
    );
    return mapDeleteResult(
      result,
      `Gasto con ID ${id} no encontrado o ya anulado`,
    );
  }

  /**
   * El reporte siempre existe: si no hubo gastos, devuelve el mes con los
   * totales en cero. Por eso no uso `mapSingleResult`, que lanzaría un 404
   * donde la respuesta correcta es "cero".
   */
  async reporteMensual(
    filtros: FiltroReporteMensualDto,
    idEmpresa?: number | null,
  ) {
    const result = await this.model.reporteMensual(filtros, idEmpresa);

    if (!result?.registro) {
      throw new NotFoundException('No se pudo generar el reporte del mes');
    }

    return result.registro;
  }
}
