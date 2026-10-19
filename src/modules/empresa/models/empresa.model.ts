import { ConflictException, Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';

export interface EmpresaRegistro {
  id: string;
  ruc: string;
  razon_social: string;
  direccion: string | null;
  logo_url: string | null;
  logo_ticket: string | null;
}

const COLUMNAS =
  'id::text AS id, ruc, razon_social, direccion, logo_url, logo_ticket';

/**
 * Hoy el sistema trabaja con una sola empresa (las sucursales usan id_empresa 1):
 * se toma la primera activa. La configuración SUNAT cuelga de esta misma fila.
 */
@Injectable()
export class EmpresaModel {
  constructor(private readonly db: DatabaseService) {}

  async obtener() {
    const result = await this.db.query<EmpresaRegistro>(
      `SELECT ${COLUMNAS} FROM gen_empresa WHERE estado = 1 ORDER BY id LIMIT 1`,
    );
    return result.rows[0] ?? null;
  }

  async guardar(
    datos: { ruc: string; razonSocial: string; direccion: string | null },
    usuario: number,
  ) {
    const actual = await this.obtener();
    try {
      const result = actual
        ? await this.db.query<EmpresaRegistro>(
            `UPDATE gen_empresa SET ruc = $2, razon_social = $3, direccion = $4,
               id_usuario_modificacion = $5, fecha_modificacion = CURRENT_TIMESTAMP
             WHERE id = $1 RETURNING ${COLUMNAS}`,
            [actual.id, datos.ruc, datos.razonSocial, datos.direccion, usuario],
          )
        : await this.db.query<EmpresaRegistro>(
            `INSERT INTO gen_empresa (ruc, razon_social, direccion, id_usuario_creacion, id_usuario_modificacion)
             VALUES ($1, $2, $3, $4, $4) RETURNING ${COLUMNAS}`,
            [datos.ruc, datos.razonSocial, datos.direccion, usuario],
          );
      return result.rows[0];
    } catch (error) {
      if ((error as { code?: string }).code === '23505') {
        throw new ConflictException(
          'Ya existe otra empresa registrada con ese RUC',
        );
      }
      throw error;
    }
  }

  async guardarLogo(
    id: string,
    logoUrl: string | null,
    logoTicket: string | null,
    usuario: number,
  ) {
    const result = await this.db.query<EmpresaRegistro>(
      `UPDATE gen_empresa SET logo_url = $2, logo_ticket = $3,
         id_usuario_modificacion = $4, fecha_modificacion = CURRENT_TIMESTAMP
       WHERE id = $1 RETURNING ${COLUMNAS}`,
      [id, logoUrl, logoTicket, usuario],
    );
    return result.rows[0];
  }
}
