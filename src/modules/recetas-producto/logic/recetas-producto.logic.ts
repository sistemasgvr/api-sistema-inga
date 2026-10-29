import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateRecetaDto,
  FiltroInsumosRecetaDto,
  GuardarRecetaInsumoDto,
} from '../dto/recetas-producto.dto';
import { RecetasProductoModel } from '../models/recetas-producto.model';

@Injectable()
export class RecetasProductoLogic {
  constructor(private readonly recetasModel: RecetasProductoModel) {}

  async listarPorProducto(idProducto: number, idEmpresa?: number | null) {
    return await this.recetasModel.listarPorProducto(idProducto, idEmpresa);
  }

  async obtenerPorId(id: number, idEmpresa?: number | null) {
    const result = await this.recetasModel.obtenerPorId(id, idEmpresa);
    return mapSingleResult(result, `Receta con ID ${id} no encontrada`);
  }

  async listarInsumosProcesados(filtros: FiltroInsumosRecetaDto) {
    return await this.recetasModel.listarInsumosProcesados(filtros);
  }

  async crearReceta(
    idProducto: number,
    dto: CreateRecetaDto,
    idEmpresa?: number | null,
  ) {
    const result = await this.recetasModel.crearReceta(
      idProducto,
      dto,
      idEmpresa,
    );
    return mapSingleResult(result, 'No se pudo crear o versionar la receta');
  }

  async guardarInsumo(
    idReceta: number,
    dto: GuardarRecetaInsumoDto,
    idEmpresa?: number | null,
  ) {
    const result = await this.recetasModel.guardarInsumo(
      idReceta,
      dto,
      idEmpresa,
    );
    return mapSingleResult(
      result,
      'No se pudo registrar el insumo en la receta',
    );
  }

  async eliminarInsumo(
    idInsumoReceta: number,
    idUsuarioAuditoria?: number,
    idEmpresa?: number | null,
  ) {
    const result = await this.recetasModel.eliminarInsumo(
      idInsumoReceta,
      idUsuarioAuditoria,
      idEmpresa,
    );
    return mapSingleResult(
      result,
      'No se pudo eliminar el insumo de la receta',
    );
  }

  async eliminarReceta(
    idReceta: number,
    idUsuarioAuditoria?: number,
    idEmpresa?: number | null,
  ) {
    const result = await this.recetasModel.eliminarReceta(
      idReceta,
      idUsuarioAuditoria,
      idEmpresa,
    );
    return mapDeleteResult(
      result,
      `Receta con ID ${idReceta} no encontrada o ya inactiva`,
    );
  }
}
