import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import {
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { FiltroSalonDto } from '../dto/salon.dto';

export type RecursoSalon = 'salon' | 'mesa';

@Injectable()
export class SalonModel {
  constructor(private readonly db: DatabaseService) {}

  sucursales(idSucursal: number) {
    return this.db.callFunctionJson('ven_sucursales_ambientes', [idSucursal]);
  }

  listar(recurso: RecursoSalon, filtros: FiltroSalonDto, idSucursal: number) {
    return this.db.callFunctionJson<AuthListResult>(
      `ven_listar_${recurso === 'salon' ? 'salones' : 'mesas'}`,
      [
        JSON.stringify({
          ...filtros,
          offset: filtros.offset,
          id_sucursal: idSucursal,
        }),
      ],
    );
  }

  obtener(recurso: RecursoSalon, id: number, idSucursal: number) {
    return this.db.callFunctionJson<AuthSingleResult>(
      `ven_obtener_${recurso}`,
      [id, idSucursal],
    );
  }

  guardar(
    recurso: RecursoSalon,
    id: number | null,
    dto: object,
    usuario: number,
    idSucursal: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>(
      `ven_guardar_${recurso}`,
      [id, JSON.stringify({ ...dto, id_sucursal_sesion: idSucursal }), usuario],
    );
  }

  estado(
    recurso: RecursoSalon,
    id: number,
    estado: number,
    usuario: number,
    idSucursal: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>(`ven_estado_${recurso}`, [
      id,
      estado,
      usuario,
      idSucursal,
    ]);
  }
}
