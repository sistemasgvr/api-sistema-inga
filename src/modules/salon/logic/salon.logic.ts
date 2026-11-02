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

  sucursales(idSucursal: number) {
    return this.model.sucursales(idSucursal);
  }

  async listar(
    recurso: RecursoSalon,
    filtros: FiltroSalonDto,
    idSucursal: number,
  ) {
    return mapListResult(
      await this.model.listar(recurso, filtros, idSucursal),
      filtros,
    );
  }

  async obtener(recurso: RecursoSalon, id: number, idSucursal: number) {
    return mapSingleResult(
      await this.model.obtener(recurso, id, idSucursal),
      'Registro no encontrado',
    );
  }

  async guardar(
    recurso: RecursoSalon,
    id: number | null,
    dto: object,
    usuario: number,
    idSucursal: number,
  ) {
    return mapSingleResult(
      await this.model.guardar(recurso, id, dto, usuario, idSucursal),
      'Registro no encontrado o inactivo',
    );
  }

  async estado(
    recurso: RecursoSalon,
    id: number,
    estado: number,
    usuario: number,
    idSucursal: number,
  ) {
    return mapSingleResult(
      await this.model.estado(recurso, id, estado, usuario, idSucursal),
      'Registro no encontrado',
    );
  }
}
