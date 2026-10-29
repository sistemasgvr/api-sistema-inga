import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';

export interface NotificacionRow {
  id: string;
  canal: string;
  titulo: string;
  mensaje: string;
  severidad: string;
  ruta: string;
  id_referencia: number | null;
  creada_en: string;
  leida?: boolean;
  ids_usuario_destino?: number[] | null;
}

@Injectable()
export class NotificacionesModel {
  constructor(private readonly db: DatabaseService) {}

  async crear(dto: {
    canal: string;
    titulo: string;
    mensaje: string;
    severidad: string;
    ruta: string;
    idReferencia: number | null;
    idsUsuario?: number[] | null;
    idEmpresa?: number | null;
  }) {
    return this.db.callFunctionJson<{ id: string | null; creada_en: string }>(
      'not_crear',
      [
        dto.canal,
        dto.titulo,
        dto.mensaje,
        dto.severidad,
        dto.ruta,
        dto.idReferencia,
        dto.idsUsuario?.length ? dto.idsUsuario : null,
        null,
        null,
        true,
        dto.idEmpresa ?? null,
      ],
    );
  }

  async listar(
    idUsuario: number,
    canales: string[],
    filtros: {
      soloNoLeidas?: boolean;
      canal?: string;
      limite?: number;
      offset?: number;
    },
    idEmpresa?: number | null,
  ) {
    return this.db.callFunctionJson<{
      registros: NotificacionRow[];
      total: number;
    }>('not_listar', [
      idUsuario,
      canales,
      filtros.soloNoLeidas ?? false,
      filtros.canal ?? null,
      filtros.limite ?? 30,
      filtros.offset ?? 0,
      idEmpresa ?? null,
    ]);
  }

  async marcarLeida(id: string, idUsuario: number) {
    return this.db.callFunctionJson<{ ok: boolean }>('not_marcar_leida', [
      id,
      idUsuario,
    ]);
  }

  async marcarTodasLeidas(
    idUsuario: number,
    canales: string[],
    canal?: string,
  ) {
    return this.db.callFunctionJson<{ ok: boolean; total: number }>(
      'not_marcar_todas_leidas',
      [idUsuario, canales, canal ?? null],
    );
  }

  async contarNoLeidas(idUsuario: number, canales: string[]) {
    return this.db.callFunctionJson<{ total: number }>('not_contar_no_leidas', [
      idUsuario,
      canales,
    ]);
  }

  async pendientesEmitir(limite = 100) {
    return this.db.callFunctionJson<{ registros: NotificacionRow[] }>(
      'not_pendientes_emitir',
      [limite],
    );
  }

  async generarRecordatorios() {
    return this.db.callFunctionJson<{ creados: number }>(
      'not_generar_recordatorios',
    );
  }

  async depurar(dias: number) {
    return this.db.callFunctionJson<{ eliminadas: number }>('not_depurar', [
      dias,
    ]);
  }
}
