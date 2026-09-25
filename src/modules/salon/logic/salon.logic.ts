import { Injectable } from '@nestjs/common';
import {
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { FiltroSalonDto } from '../dto/salon.dto';
import { RecursoSalon, SalonModel } from '../models/salon.model';

@Injectable()
export class SalonLogic {
  constructor(private readonly model: SalonModel) {}

  sucursales() {
    return this.model.sucursales();
  }

  async listar(recurso: RecursoSalon, filtros: FiltroSalonDto) {
    return mapListResult(await this.model.listar(recurso, filtros), filtros);
  }

  async obtener(recurso: RecursoSalon, id: number) {
    return mapSingleResult(
      await this.model.obtener(recurso, id),
      'Registro no encontrado',
    );
  }

  async guardar(
    recurso: RecursoSalon,
    id: number | null,
    dto: object,
    usuario: number,
  ) {
    return mapSingleResult(
      await this.model.guardar(recurso, id, dto, usuario),
      'Registro no encontrado o inactivo',
    );
  }

  async estado(
    recurso: RecursoSalon,
    id: number,
    estado: number,
    usuario: number,
  ) {
    return mapSingleResult(
      await this.model.estado(recurso, id, estado, usuario),
      'Registro no encontrado',
    );
  }
}
