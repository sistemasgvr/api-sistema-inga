import {
  Injectable,
  Logger,
  NotFoundException,
  StreamableFile,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import { SupabaseStorageService } from '../../../integrations/supabase-storage/supabase-storage.service';
import { EmpresaLogic } from '../../empresa/logic/empresa.logic';
import {
  formatearComanda,
  type ComandaImpresion,
} from '../helpers/ticket-formato';
import { ticketPdf, type ImagenTicket } from '../helpers/ticket-pdf';
import {
  TicketPdfModel,
  type TicketArchivable,
} from '../models/ticket-pdf.model';

export interface PdfTicket {
  nombre: string;
  pdf: Buffer;
}

const CARPETA = {
  COMPROBANTE: 'comprobantes',
  PRECUENTA: 'precuentas',
} as const;

/** Respuesta HTTP del PDF; `inline` lo abre en el navegador y conserva el nombre al guardarlo. */
export function archivoPdf({ nombre, pdf }: PdfTicket) {
  return new StreamableFile(pdf, {
    type: 'application/pdf',
    disposition: `inline; filename="${nombre}.pdf"`,
    length: pdf.length,
  });
}

/**
 * PDF con forma de ticket (58 mm). Se genera una vez, se guarda en Storage y las
 * siguientes consultas lo leen de ahí: el documento queda tal como se emitió,
 * aunque después cambien el logo o los datos de la empresa.
 */
@Injectable()
export class TicketPdfLogic {
  private readonly logger = new Logger(TicketPdfLogic.name);

  constructor(
    private readonly model: TicketPdfModel,
    private readonly empresa: EmpresaLogic,
    private readonly storage: SupabaseStorageService,
  ) {}

  /** Comanda, precuenta o ticket de comprobante enviado a la cola de impresión. */
  async trabajo(idComanda: number): Promise<PdfTicket> {
    const registro = await this.model.trabajo(idComanda);
    if (!registro)
      throw new NotFoundException('Esta comanda no tiene un ticket generado');
    return this.archivado(registro, (ruta) =>
      this.model.guardarTrabajo(idComanda, ruta),
    );
  }

  async comprobante(idComprobante: number): Promise<PdfTicket> {
    const registro = await this.model.comprobante(idComprobante);
    if (!registro) throw new NotFoundException('El comprobante no existe');
    return this.archivado(registro, (ruta) =>
      this.model.guardarComprobante(idComprobante, ruta),
    );
  }

  /** Archiva en segundo plano los comprobantes recién emitidos; un fallo no afecta al cobro. */
  archivarComprobantes(idPedido: number) {
    void (async () => {
      for (const id of await this.model.comprobantesSinPdf(idPedido))
        await this.comprobante(id);
    })().catch((error: Error) =>
      this.logger.warn(
        `No se archivó el PDF del pedido ${idPedido}: ${error.message}`,
      ),
    );
  }

  /** Los datos impresos cambiaron (p. ej. medio de pago): se descarta el PDF y se vuelve a archivar. */
  async regenerarComprobantes(idPedido: number) {
    const viejos = await this.model.invalidarComprobantes(idPedido);
    await this.storage
      .remove(viejos)
      .catch((error: Error) =>
        this.logger.warn(`No se borraron PDF anteriores: ${error.message}`),
      );
    this.archivarComprobantes(idPedido);
  }

  private async archivado(
    { contenido, ruta_pdf }: TicketArchivable,
    guardar: (ruta: string) => Promise<boolean>,
  ): Promise<PdfTicket> {
    const nombre = this.nombre(contenido);
    if (ruta_pdf) {
      try {
        return { nombre, pdf: await this.storage.download(ruta_pdf) };
      } catch (error) {
        // Si el archivo se perdió, se regenera desde la copia guardada en la base.
        this.logger.warn(
          `PDF archivado no disponible (${ruta_pdf}): ${(error as Error).message}`,
        );
      }
    }
    const pdf = await this.generar(contenido, nombre);
    if (!ruta_pdf && this.storage.isConfigured()) {
      try {
        const carpeta =
          (contenido.tipo && CARPETA[contenido.tipo]) ?? 'comandas';
        const { path } = await this.storage.upload(
          `tickets/${carpeta}/${nombre}_${randomUUID()}.pdf`,
          pdf,
          'application/pdf',
          false,
        );
        if (!(await guardar(path))) await this.storage.remove([path]);
      } catch (error) {
        // La descarga no debe fallar por Storage; se archivará en la próxima consulta.
        this.logger.warn(
          `No se archivó ${nombre}: ${(error as Error).message}`,
        );
      }
    }
    return { nombre, pdf };
  }

  private nombre(contenido: ComandaImpresion) {
    const tipo =
      contenido.tipo === 'COMPROBANTE'
        ? 'comprobante'
        : contenido.tipo === 'PRECUENTA'
          ? 'precuenta'
          : 'comanda';
    const referencia = contenido.comprobante?.numero ?? contenido.pedido;
    return `${tipo}-${referencia}-${contenido.id}`.replace(/[^\w-]+/g, '_');
  }

  private async generar(contenido: ComandaImpresion, nombre: string) {
    const empresa = await this.empresa.datosTicket();
    return ticketPdf(
      formatearComanda(contenido, empresa),
      empresa.logo ? await this.logo(empresa.logo) : null,
      nombre,
    );
  }

  private async logo(base64: string): Promise<ImagenTicket | null> {
    try {
      const { data, info } = await sharp(Buffer.from(base64, 'base64'))
        .flatten({ background: '#ffffff' })
        .jpeg({ quality: 90 })
        .toBuffer({ resolveWithObject: true });
      return { jpeg: data, ancho: info.width, alto: info.height };
    } catch {
      return null; // Sin logo el ticket se genera igual, como en la impresora.
    }
  }
}
