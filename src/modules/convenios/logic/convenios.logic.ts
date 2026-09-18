import { Injectable } from '@nestjs/common';
import {
  mapActivateResult,
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateConvenioDto,
  FiltroConveniosDto,
  UpdateConvenioDto,
} from '../dto/convenios.dto';
import { ConveniosModel } from '../models/convenios.model';

/**
 * Orquesta las llamadas al modelo y convierte lo que devuelve la base en la
 * respuesta HTTP correcta.
 *
 * Los helpers `map*Result` son los que traducen el `{ error: '...' }` que
 * devuelven las funciones SQL en un 400 o un 404 de verdad. Gracias a eso el
 * mensaje que escribí en el plpgsql llega tal cual al usuario final.
 */
@Injectable()
export class ConveniosLogic {
  constructor(private readonly conveniosModel: ConveniosModel) {}

  async listar(filtros: FiltroConveniosDto) {
    const result = await this.conveniosModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.conveniosModel.obtenerPorId(id);
    return mapSingleResult(result, `Convenio con ID ${id} no encontrado`);
  }

  async listarCondicionesPago() {
    return await this.conveniosModel.listarCondicionesPago();
  }

  async crear(dto: CreateConvenioDto) {
    const result = await this.conveniosModel.crear(
      dto.codigo,
      dto.nombre,
      dto.id_condicion_pago,
      dto.limite_credito ?? 0,
      dto.corte_quincenal ?? true,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo crear el convenio');
  }

  async actualizar(id: number, dto: UpdateConvenioDto) {
    const result = await this.conveniosModel.actualizar(
      id,
      dto.codigo ?? null,
      dto.nombre ?? null,
      dto.id_condicion_pago ?? null,
      // Uso `?? null` y no `|| null` a propósito: con `||`, un límite de
      // crédito de 0 (que es válido y significa "sin tope") se convertiría en
      // null y la base lo tomaría como "no me lo mandaron", dejando el valor
      // anterior sin cambiar.
      dto.limite_credito ?? null,
      dto.corte_quincenal ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Convenio con ID ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.conveniosModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(
      result,
      `Convenio con ID ${id} no encontrado o ya inactivo`,
    );
  }

  async activar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.conveniosModel.activar(id, idUsuarioAuditoria);
    return mapActivateResult(
      result,
      `Convenio con ID ${id} no encontrado o ya activo`,
    );
  }
}
