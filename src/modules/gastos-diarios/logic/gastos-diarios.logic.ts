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
  FiltroProductosInventarioDto,
  FiltroReporteDiaDto,
  UpdateInsumoDto,
} from '../dto/gastos-diarios.dto';
import { GastosDiariosModel } from '../models/gastos-diarios.model';
import { NotificacionesLogic } from '../../notificaciones/logic/notificaciones.logic';
import { RutasNotificacion } from '../../notificaciones/constants/rutas-notificacion';

@Injectable()
export class GastosDiariosLogic {
  constructor(
    private readonly model: GastosDiariosModel,
    private readonly notificaciones: NotificacionesLogic,
  ) {}

  /* -------------------------------- Insumos -------------------------------- */

  async listarInsumos(filtros: FiltroInsumosDto, idEmpresa?: number | null) {
    return await this.model.listarInsumos(filtros, idEmpresa);
  }


  async listarProductosInventario(filtros: FiltroProductosInventarioDto) {
    return await this.model.listarProductosInventario(filtros);
  }

  async obtenerInsumo(id: number, idEmpresa?: number | null) {
    const result = await this.model.obtenerInsumo(id, idEmpresa);
    return mapSingleResult(result, `Insumo con ID ${id} no encontrado`);
  }

  async crearInsumo(dto: CreateInsumoDto, idEmpresa?: number | null) {
    const result = await this.model.crearInsumo(dto, idEmpresa);
    return mapSingleResult(result, 'No se pudo crear el insumo');
  }

  async actualizarInsumo(id: number, dto: UpdateInsumoDto, idEmpresa?: number | null) {
    const result = await this.model.actualizarInsumo(id, dto, idEmpresa);
    return mapSingleResult(result, `Insumo con ID ${id} no encontrado`);
  }

  async toggleInsumo(id: number, idUsuarioAuditoria?: number, idEmpresa?: number | null) {
    const result = await this.model.toggleInsumo(id, idUsuarioAuditoria, idEmpresa);
    return mapDeleteResult(result, `Insumo con ID ${id} no encontrado`);
  }

  /* ------------------------------ Gasto del día ---------------------------- */

  async abrirDia(dto: AbrirDiaDto) {
    const result = await this.model.abrirDia(dto);
    return mapSingleResult(result, 'No se pudo abrir el gasto del día');
  }

  async obtenerDia(id: number, idEmpresa?: number | null) {
    const result = await this.model.obtenerDia(id, idEmpresa);
    return mapSingleResult(result, `Gasto del día con ID ${id} no encontrado`);
  }

  async listarDias(filtros: FiltroDiasDto, idEmpresa?: number | null) {
    const result = await this.model.listarDias(filtros, idEmpresa);
    return mapListResult(result, filtros);
  }

  async agregarLinea(idGastoDia: number, dto: CreateLineaDto) {
    const result = await this.model.agregarLinea(idGastoDia, dto);
    const registro = mapSingleResult(result, 'No se pudo agregar la compra');
    this.notificaciones
      .emitir({
        canal: 'gastos-diarios',
        titulo: 'Compra registrada',
        mensaje: 'Se registró una compra en los gastos del día.',
        severidad: 'info',
        ruta: RutasNotificacion.gastosDiarios(),
        idReferencia: (registro as { id?: number })?.id ?? null,
      })
      ?.catch(() => undefined);
    // Una compra con inventario mueve stock: la alerta de mínimo sale al instante.
    void this.notificaciones.despachar();
    return registro;
  }

  async anularLinea(id: number, motivo?: string, idUsuarioAuditoria?: number) {
    const result = await this.model.anularLinea(id, motivo, idUsuarioAuditoria);
    return mapSingleResult(result, `Línea con ID ${id} no encontrada`);
  }


  async reporteDia(filtros: FiltroReporteDiaDto) {
    const result = await this.model.reporteDia(filtros);

    if (!result?.registro) {
      throw new NotFoundException('No se pudo generar el reporte del día');
    }

    return result.registro;
  }
}
