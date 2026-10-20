import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import type { ComandaImpresion } from '../helpers/ticket-formato';

export interface TicketArchivable {
  contenido: ComandaImpresion;
  ruta_pdf: string | null;
}

/** Rutas en Storage de los PDF archivados de tickets y comprobantes. */
@Injectable()
export class TicketPdfModel {
  constructor(private readonly db: DatabaseService) {}

  async trabajo(idComanda: number) {
    const result = await this.db.query<TicketArchivable>(
      `SELECT contenido, ruta_pdf FROM ven_impresion_trabajo
       WHERE id_comanda=$1::bigint`,
      [idComanda],
    );
    return result.rows[0] ?? null;
  }

  async comprobante(idComprobante: number) {
    const result = await this.db.query<TicketArchivable>(
      `SELECT ven_ticket_comprobante(id) AS contenido, ruta_pdf
       FROM ven_comprobante WHERE id=$1::bigint`,
      [idComprobante],
    );
    return result.rows[0] ?? null;
  }

  /** Comprobantes vigentes del pedido que todavía no tienen PDF archivado. */
  async comprobantesSinPdf(idPedido: number) {
    const result = await this.db.query<{ id: string }>(
      `SELECT id::text AS id FROM ven_comprobante
       WHERE id_pedido=$1::bigint AND estado=1 AND ruta_pdf IS NULL`,
      [idPedido],
    );
    return result.rows.map((row) => Number(row.id));
  }

  // Sólo se guarda si nadie archivó antes: si dos pedidos llegan a la vez, gana el primero.
  async guardarTrabajo(idComanda: number, ruta: string) {
    const result = await this.db.query(
      `UPDATE ven_impresion_trabajo SET ruta_pdf=$2
       WHERE id_comanda=$1::bigint AND ruta_pdf IS NULL`,
      [idComanda, ruta],
    );
    return Boolean(result.rowCount);
  }

  async guardarComprobante(idComprobante: number, ruta: string) {
    const result = await this.db.query(
      `UPDATE ven_comprobante SET ruta_pdf=$2
       WHERE id=$1::bigint AND ruta_pdf IS NULL`,
      [idComprobante, ruta],
    );
    return Boolean(result.rowCount);
  }

  /** Quita la referencia a los PDF del pedido (p. ej. cambió el medio de pago) y devuelve las rutas viejas. */
  async invalidarComprobantes(idPedido: number) {
    const result = await this.db.query<{ ruta_pdf: string }>(
      `WITH viejo AS (
         SELECT id, ruta_pdf FROM ven_comprobante
         WHERE id_pedido=$1::bigint AND ruta_pdf IS NOT NULL FOR UPDATE
       ) UPDATE ven_comprobante c SET ruta_pdf=NULL FROM viejo v
         WHERE c.id=v.id RETURNING v.ruta_pdf`,
      [idPedido],
    );
    return result.rows.map((row) => row.ruta_pdf);
  }
}
