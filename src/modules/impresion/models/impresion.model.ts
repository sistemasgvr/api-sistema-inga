import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';

@Injectable()
export class ImpresionModel {
  constructor(private readonly db: DatabaseService) {}

  async configuracionQz() {
    const result = await this.db.query<{
      certificado: string;
      clave_privada: string;
      actualizado: Date;
    }>(
      'SELECT certificado, clave_privada, actualizado FROM gen_qz_configuracion WHERE id=1',
    );
    return result.rows[0] ?? null;
  }

  async guardarConfiguracionQz(certificado: string, clave: string) {
    try {
      await this.db.query(
        `INSERT INTO gen_qz_configuracion (id, certificado, clave_privada) VALUES (1,$1,$2)
       ON CONFLICT (id) DO UPDATE SET certificado=$1, clave_privada=$2, actualizado=now()`,
        [certificado, clave],
      );
    } catch {
      // No propagar detalles SQL que podrían contener la clave privada.
      throw new ServiceUnavailableException(
        'No se pudo guardar la configuración QZ. Verifica la migración y los permisos de la base de datos.',
      );
    }
  }

  async tomar(estaciones: number[], propietario: string) {
    // Una sola sentencia y SKIP LOCKED protegen incluso con varios procesos del VPS.
    const result = await this.db.query<{
      id: string;
      id_estacion: number;
      ancho_papel: number;
      host: string;
      contenido: Record<string, unknown>;
    }>(
      `
      WITH siguiente AS (
        SELECT t.id_comanda FROM ven_impresion_trabajo t
        JOIN gen_estacion e ON e.id=t.id_estacion
        JOIN ven_comanda c ON c.id=t.id_comanda
        JOIN ven_pedido p ON p.id=c.id_pedido
        WHERE t.estado='pendiente' AND t.id_estacion=ANY($1::bigint[])
          AND e.estado=1 AND NULLIF(trim(e.impresora_ip),'') IS NOT NULL
          AND c.estado=1 AND p.estado=1 AND p.estado_pedido<>5
        ORDER BY t.id_comanda FOR UPDATE OF t SKIP LOCKED LIMIT 1
      ), tomado AS (
        UPDATE ven_impresion_trabajo t SET estado='procesando', propietario=$2::uuid,
          intentos=intentos+1, error=NULL, actualizado=now()
        FROM siguiente s WHERE t.id_comanda=s.id_comanda RETURNING t.*
      ) SELECT t.id_comanda::text AS id, t.id_estacion::int AS id_estacion,
          t.contenido, e.impresora_ip AS host, e.ancho_papel
        FROM tomado t JOIN gen_estacion e ON e.id=t.id_estacion`,
      [estaciones, propietario],
    );
    return result.rows[0] ?? null;
  }

  async confirmar(
    id: string,
    propietario: string,
    enviado: boolean,
    error?: string,
    reintentable = false,
  ) {
    // «reintentable»: el ticket no llegó a la impresora (p. ej. falló la firma QZ);
    // vuelve a la cola sin revisión manual porque no hay riesgo de duplicarlo.
    const estado = enviado
      ? 'enviado'
      : reintentable
        ? 'pendiente'
        : 'revision';
    const result = await this.db.query<{ id: string }>(
      `
      WITH actualizado AS (
        UPDATE ven_impresion_trabajo SET estado=$3, error=$4, actualizado=now()
        WHERE id_comanda=$1::bigint AND propietario=$2::uuid
          AND (estado='procesando' OR estado=$3) RETURNING id_comanda
      ) UPDATE ven_comanda SET fecha_impresion=CASE WHEN $3='enviado' THEN now() ELSE fecha_impresion END
        WHERE id IN (SELECT id_comanda FROM actualizado) RETURNING id`,
      [id, propietario, estado, error?.slice(0, 500) ?? null],
    );
    return Boolean(result.rowCount);
  }

  async pendientes(estaciones: number[]) {
    return (
      await this.db.query<{
        id: string;
        id_estacion: string;
        estacion: string;
        pedido: string;
        estado: string;
        error: string | null;
        actualizado: Date;
      }>(
        `
      SELECT t.id_comanda::text AS id, t.id_estacion, e.nombre AS estacion,
        t.contenido->>'pedido' AS pedido, t.estado, t.error, t.actualizado
      FROM ven_impresion_trabajo t JOIN gen_estacion e ON e.id=t.id_estacion
      JOIN ven_comanda c ON c.id=t.id_comanda JOIN ven_pedido p ON p.id=c.id_pedido
      WHERE t.id_estacion=ANY($1::bigint[]) AND t.estado<>'enviado'
        AND c.estado=1 AND p.estado=1 AND p.estado_pedido<>5
      ORDER BY t.id_comanda LIMIT 100`,
        [estaciones],
      )
    ).rows;
  }

  async resolver(id: string, enviado: boolean) {
    // Nunca reasignar automáticamente un envío incierto: podría haber salido en papel.
    const result = await this.db.query<{ id: string }>(
      `
      WITH resuelto AS (
        UPDATE ven_impresion_trabajo SET estado=$2, propietario=NULL,error=NULL,actualizado=now()
        WHERE id_comanda=$1::bigint AND
          (estado='revision' OR (estado='procesando' AND actualizado<now()-interval '2 minutes'))
        RETURNING id_comanda
      ) UPDATE ven_comanda SET fecha_impresion=CASE WHEN $2='enviado' THEN now() ELSE fecha_impresion END
        WHERE id IN (SELECT id_comanda FROM resuelto) RETURNING id`,
      [id, enviado ? 'enviado' : 'pendiente'],
    );
    return Boolean(result.rowCount);
  }
  async impresoraActiva(host: string) {
    const result = await this.db.query<{ existe: number }>(
      'SELECT 1 AS existe FROM gen_estacion WHERE estado=1 AND trim(impresora_ip)=$1 LIMIT 1',
      [host],
    );
    return Boolean(result.rowCount);
  }
}
