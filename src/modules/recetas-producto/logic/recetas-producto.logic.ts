import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { CreateRecetaDto, GuardarRecetaInsumoDto } from '../dto/recetas-producto.dto';
import { RecetasProductoModel } from '../models/recetas-producto.model';

@Injectable()
export class RecetasProductoLogic {
  constructor(private readonly recetasModel: RecetasProductoModel) {}

  async listarPorProducto(idProducto: number) {
    return await this.recetasModel.listarPorProducto(idProducto);
  }

  async obtenerPorId(id: number) {
    const result = await this.recetasModel.obtenerPorId(id);
    return mapSingleResult(result, `Receta con ID ${id} no encontrada`);
  }

  async listarInsumosProcesados(busqueda: string) {
    return await this.recetasModel.listarInsumosProcesados(busqueda);
  }

  async crearReceta(idProducto: number, dto: CreateRecetaDto) {
    const result = await this.recetasModel.crearReceta(idProducto, dto);
    return mapSingleResult(result, 'No se pudo crear o versionar la receta');
  }

  async guardarInsumo(idReceta: number, dto: GuardarRecetaInsumoDto) {
    const result = await this.recetasModel.guardarInsumo(idReceta, dto);
    return mapSingleResult(result, 'No se pudo registrar el insumo en la receta');
  }

  async eliminarInsumo(idInsumoReceta: number, idUsuarioAuditoria?: number) {
    const result = await this.recetasModel.eliminarInsumo(idInsumoReceta, idUsuarioAuditoria);
    return mapSingleResult(result, 'No se pudo eliminar el insumo de la receta');
  }

  async eliminarReceta(idReceta: number, idUsuarioAuditoria?: number) {
    const result = await this.recetasModel.eliminarReceta(idReceta, idUsuarioAuditoria);
    return mapDeleteResult(result, `Receta con ID ${idReceta} no encontrada o ya inactiva`);
  }
}