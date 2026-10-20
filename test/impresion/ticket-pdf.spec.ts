import { NotFoundException, StreamableFile } from '@nestjs/common';
import sharp from 'sharp';
import { SupabaseStorageService } from '../../src/integrations/supabase-storage/supabase-storage.service';
import { EmpresaLogic } from '../../src/modules/empresa/logic/empresa.logic';
import {
  formatearComanda,
  type ComandaImpresion,
} from '../../src/modules/impresion/helpers/ticket-formato';
import { ticketPdf } from '../../src/modules/impresion/helpers/ticket-pdf';
import {
  archivoPdf,
  TicketPdfLogic,
} from '../../src/modules/impresion/logic/ticket-pdf.logic';
import { TicketPdfModel } from '../../src/modules/impresion/models/ticket-pdf.model';

const comprobante: ComandaImpresion = {
  tipo: 'COMPROBANTE',
  id: '16',
  numero: 1,
  pedido: 'PED-31',
  mesa: 'M5',
  estacion: 'CAJA',
  fecha: '2026-10-19T22:58:49Z',
  tipo_pedido: 1,
  total: 41.5,
  comprobante: {
    nombre_tipo: 'BOLETA DE VENTA',
    numero: 'B001-00000012',
    receptor_razon_social: 'Juan (cliente)',
    receptor_num_doc: '45678912',
    monto_gravado: 35.17,
    monto_igv: 6.33,
    monto_total: 41.5,
  },
  pagos: [{ nombre_medio: 'Efectivo', monto: 41.5 }],
  items: [
    { cantidad: 2, nombre_producto: 'Arroz con pato', monto_subtotal: 41.5 },
  ],
};
const texto = (pdf: Buffer) => pdf.toString('latin1');

describe('PDF de tickets', () => {
  it('el PDF de 58 mm usa 32 columnas, igual que el papel', () => {
    const s = texto(
      ticketPdf(formatearComanda(comprobante, null, 58), null, 'T', 58),
    );
    expect(s).toMatch(/\/MediaBox \[0 0 164\.41 [\d.]+\]/);
    expect(s).toContain(`(${'-'.repeat(32)}) Tj`);
  });

  it('genera un PDF de 80 mm (48 columnas) con xref exacto y paréntesis escapados', () => {
    const s = texto(ticketPdf(formatearComanda(comprobante, null)));
    expect(s.startsWith('%PDF-1.4')).toBe(true);
    expect(s).toMatch(/\/MediaBox \[0 0 226\.77 [\d.]+\]/);
    expect(s).toContain(`(${'-'.repeat(48)}) Tj`);
    expect(s).toContain(String.raw`(Cliente: Juan \(cliente\)) Tj`);
    const xref = Number(/startxref\n(\d+)/.exec(s)![1]);
    expect(s.slice(xref).startsWith('xref')).toBe(true);
    [...s.slice(xref).matchAll(/(\d{10}) 00000 n/g)].forEach((m, i) =>
      expect(s.slice(Number(m[1])).startsWith(`${i + 1} 0 obj`)).toBe(true),
    );
  });

  describe('archivo en Storage', () => {
    const model = {
      trabajo: jest.fn(),
      comprobante: jest.fn(),
      guardarComprobante: jest.fn(),
      guardarTrabajo: jest.fn(),
    };
    const storage = {
      isConfigured: jest.fn(),
      download: jest.fn(),
      upload: jest.fn(),
      remove: jest.fn(),
    };
    const empresa = { datosTicket: jest.fn() };
    const logic = new TicketPdfLogic(
      model as unknown as TicketPdfModel,
      empresa as unknown as EmpresaLogic,
      storage as unknown as SupabaseStorageService,
    );
    beforeEach(() => {
      jest.resetAllMocks();
      storage.isConfigured.mockReturnValue(true);
      storage.upload.mockImplementation((path: string) => ({ path }));
      empresa.datosTicket.mockResolvedValue({
        ruc: '20123456789',
        razon_social: 'Inga SAC',
        direccion: null,
        logo: null,
      });
    });

    it('si ya está archivado lo lee de Storage sin volver a generarlo', async () => {
      const archivado = Buffer.from('%PDF-archivado');
      model.comprobante.mockResolvedValue({
        contenido: comprobante,
        ruta_pdf: 'tickets/comprobantes/x.pdf',
      });
      storage.download.mockResolvedValue(archivado);
      const { nombre, pdf } = await logic.comprobante(16);
      expect(pdf).toBe(archivado);
      expect(nombre).toBe('comprobante-B001-00000012-16');
      expect(storage.download).toHaveBeenCalledWith(
        'tickets/comprobantes/x.pdf',
      );
      expect(storage.upload).not.toHaveBeenCalled();
      expect(empresa.datosTicket).not.toHaveBeenCalled();
    });

    it('la primera vez lo genera, lo sube y guarda la ruta', async () => {
      model.comprobante.mockResolvedValue({
        contenido: comprobante,
        ruta_pdf: null,
      });
      model.guardarComprobante.mockResolvedValue(true);
      const { pdf } = await logic.comprobante(16);
      expect(texto(pdf)).toContain('(B001-00000012) Tj');
      const [ruta, cuerpo, tipo, upsert] = storage.upload.mock.calls[0] as [
        string,
        Buffer,
        string,
        boolean,
      ];
      expect(ruta).toMatch(
        /^tickets\/comprobantes\/comprobante-B001-00000012-16_[0-9a-f-]{36}\.pdf$/,
      );
      expect(cuerpo).toBe(pdf);
      expect([tipo, upsert]).toEqual(['application/pdf', false]);
      expect(model.guardarComprobante).toHaveBeenCalledWith(16, ruta);
      expect(storage.remove).not.toHaveBeenCalled();
    });

    it('si otra solicitud ya lo archivó, borra su copia para no dejar huérfanos', async () => {
      model.trabajo.mockResolvedValue({
        contenido: { ...comprobante, tipo: undefined, comprobante: undefined },
        ruta_pdf: null,
      });
      model.guardarTrabajo.mockResolvedValue(false);
      await logic.trabajo(66);
      const [ruta] = storage.upload.mock.calls[0] as [string];
      expect(ruta.startsWith('tickets/comandas/comanda-PED-31-16_')).toBe(true);
      expect(storage.remove).toHaveBeenCalledWith([ruta]);
    });

    it('si Storage falla, igual entrega el PDF', async () => {
      model.comprobante.mockResolvedValue({
        contenido: comprobante,
        ruta_pdf: null,
      });
      storage.upload.mockRejectedValue(new Error('sin red'));
      const { pdf } = await logic.comprobante(16);
      expect(texto(pdf).startsWith('%PDF')).toBe(true);
      expect(model.guardarComprobante).not.toHaveBeenCalled();
    });

    it('incrusta el logo de la empresa convertido a JPEG', async () => {
      const png = await sharp({
        create: { width: 40, height: 20, channels: 3, background: '#000' },
      })
        .png()
        .toBuffer();
      empresa.datosTicket.mockResolvedValue({
        ruc: null,
        razon_social: null,
        direccion: null,
        logo: png.toString('base64'),
      });
      model.comprobante.mockResolvedValue({
        contenido: comprobante,
        ruta_pdf: null,
      });
      const { pdf } = await logic.comprobante(16);
      expect(texto(pdf)).toMatch(
        /\/Width 40 \/Height 20 .*\/Filter \/DCTDecode/,
      );
    });

    it('responde 404 si el comprobante no existe', async () => {
      model.comprobante.mockResolvedValue(null);
      await expect(logic.comprobante(999)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('la respuesta HTTP es un PDF con nombre de archivo', () => {
      const archivo = archivoPdf({
        nombre: 'comprobante-B001-1',
        pdf: Buffer.from('x'),
      });
      expect(archivo).toBeInstanceOf(StreamableFile);
      expect(archivo.getHeaders()).toMatchObject({
        type: 'application/pdf',
        disposition: 'inline; filename="comprobante-B001-1.pdf"',
      });
    });
  });
});
