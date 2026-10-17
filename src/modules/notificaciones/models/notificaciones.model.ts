import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';

@Injectable()
export class NotificacionesModel {
  constructor(private readonly db: DatabaseService) {}

  async crear(dto: { canal: string; titulo: string; mensaje: string; severidad: string; ruta: string; idReferencia: number | null }) {
    const result = await this.db.callFunctionJson<{ id: string }>('not_crear', [
      dto.canal, dto.titulo, dto.mensaje, dto.severidad, dto.ruta, dto.idReferencia,
    ]);
    return result.id;
  }

  async listar(idUsuario: number, canales: string[]) {
    return this.db.callFunctionJson<{ registros: any[]; total: number }>('not_listar', [idUsuario, canales]);
  }

  async marcarLeida(id: string, idUsuario: number) {
    return this.db.callFunctionJson<{ ok: boolean }>('not_marcar_leida', [id, idUsuario]);
  }

  async contarNoLeidas(idUsuario: number, canales: string[]) {
    return this.db.callFunctionJson<{ total: number }>('not_contar_no_leidas', [idUsuario, canales]);
  }
}
