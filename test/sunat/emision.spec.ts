import {
  BadRequestException,
  ConflictException,
  ServiceUnavailableException,
} from '@nestjs/common';
import {
  ApisPeruFallo,
  ApisPeruService,
} from '../../src/integrations/apisperu/apisperu.service';
import { NotificacionesLogic } from '../../src/modules/notificaciones/logic/notificaciones.logic';
import { EstadoSunat } from '../../src/modules/sunat/constants/sunat';
import { SunatArchivosLogic } from '../../src/modules/sunat/logic/sunat-archivos.logic';
import { SunatConfiguracionLogic } from '../../src/modules/sunat/logic/sunat-configuracion.logic';
import { SunatEmisionLogic } from '../../src/modules/sunat/logic/sunat-emision.logic';
import {
  SunatComprobantesModel,
  type ComprobanteEstado,
} from '../../src/modules/sunat/models/sunat-comprobantes.model';
import { SunatLotesModel } from '../../src/modules/sunat/models/sunat-lotes.model';

const emisor = {
  ruc: '20123456789',
  razonSocial: 'INGA SAC',
  nombreComercial: null,
  direccion: 'Av. 1',
  ubigeo: '150101',
  departamento: 'LIMA',
  provincia: 'LIMA',
  distrito: 'LIMA',
};

const comprobante = (estadoSunat: number): ComprobanteEstado => ({
  id: 9,
  idEmpresa: 1,
  idPedido: 4,
  tipoComprobante: 2,
  serie: 'F001',
  correlativo: '00000003',
  fechaEmision: '2026-10-28T15:00:00Z',
  receptorTipoDoc: 6,
  receptorNumDoc: '20555555555',
  receptorRazonSocial: 'CLIENTE SAC',
  receptorDireccion: null,
  estado: 1,
  estadoSunat,
  formaEnvio: null,
  montoIgv: 18,
  montoTotal: 118,
  hash: null,
  rutaXml: null,
  rutaCdr: null,
  rutaPdfA4: null,
  fechaLimiteEnvio: '2026-11-04',
  codigoRespuesta: null,
  mensaje: null,
  observaciones: null,
  intentos: 0,
  fechaEnvio: null,
  lineas: [
    {
      idProducto: 1,
      descripcion: 'Menú',
      cantidad: 1,
      unidadSunat: 'NIU',
      tipoAfectacionIgv: '10',
      tasaIgv: 18,
      valorUnitario: 100,
      precioUnitarioIgv: 118,
      montoBaseIgv: 100,
      montoIgv: 18,
    },
  ],
});

describe('Envío individual a SUNAT', () => {
  const model = {
    comprobante: jest.fn(),
    reservarEnvio: jest.fn(),
    guardarResultado: jest.fn(),
    bitacora: jest.fn(),
  };
  const apisPeru = { enviarFactura: jest.fn(), estadoFactura: jest.fn() };
  const archivos = {
    guardar: jest.fn((ruta: string) => Promise.resolve(ruta)),
  };
  const notificaciones = { emitir: jest.fn() };
  const configuracion = {
    contexto: jest.fn(() => Promise.resolve({ emisor, token: 'tk' })),
  };
  const logic = new SunatEmisionLogic(
    model as unknown as SunatComprobantesModel,
    {} as SunatLotesModel,
    configuracion as unknown as SunatConfiguracionLogic,
    apisPeru as unknown as ApisPeruService,
    archivos as unknown as SunatArchivosLogic,
    notificaciones as unknown as NotificacionesLogic,
  );

  beforeEach(() => {
    jest.clearAllMocks();
    model.reservarEnvio.mockResolvedValue(true);
  });

  it('guarda XML, CDR y hash cuando SUNAT acepta', async () => {
    model.comprobante
      .mockResolvedValueOnce(comprobante(EstadoSunat.PENDIENTE))
      .mockResolvedValue(comprobante(EstadoSunat.ACEPTADO));
    apisPeru.enviarFactura.mockResolvedValue({
      xml: '<Invoice/>',
      hash: 'h4sh',
      sunatResponse: {
        success: true,
        cdrZip: Buffer.from('zip').toString('base64'),
        cdrResponse: { accepted: true, code: '0', description: 'Aceptada' },
      },
    });
    const r = await logic.enviar(9, 3);
    const [[, documento]] = apisPeru.enviarFactura.mock.calls as unknown[][];
    expect(documento).toMatchObject({
      tipoDoc: '01',
      correlativo: '3',
      mtoImpVenta: 118,
    });
    expect(model.guardarResultado).toHaveBeenCalledWith(9, {
      estadoSunat: EstadoSunat.ACEPTADO,
      codigo: '0',
      mensaje: 'Aceptada',
      observaciones: null,
      hash: 'h4sh',
      rutaXml: 'sunat/20123456789/xml/20123456789-01-F001-3.xml',
      rutaCdr: 'sunat/20123456789/cdr/R-20123456789-01-F001-3.zip',
    });
    expect(r.estadoSunat).toBe(EstadoSunat.ACEPTADO);
    expect(notificaciones.emitir).not.toHaveBeenCalled();
  });

  it('si APIsPERU no responde lo deja pendiente para reintentar', async () => {
    model.comprobante.mockResolvedValue(comprobante(EstadoSunat.PENDIENTE));
    apisPeru.enviarFactura.mockRejectedValue(
      new ApisPeruFallo(
        'No se pudo comunicar con APIsPERU: timeout',
        null,
        true,
      ),
    );
    await expect(logic.enviar(9, 3)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
    expect(model.guardarResultado).toHaveBeenCalledWith(9, {
      estadoSunat: EstadoSunat.PENDIENTE,
      mensaje: 'No se pudo comunicar con APIsPERU: timeout',
    });
  });

  it('avisa el rechazo de SUNAT', async () => {
    model.comprobante.mockResolvedValue(comprobante(EstadoSunat.PENDIENTE));
    apisPeru.enviarFactura.mockResolvedValue({
      sunatResponse: {
        success: false,
        error: { code: '2017', message: 'RUC inválido' },
      },
    });
    await logic.enviar(9, 3);
    expect(model.guardarResultado).toHaveBeenCalledWith(
      9,
      expect.objectContaining({
        estadoSunat: EstadoSunat.RECHAZADO,
        rutaXml: null,
      }),
    );
    expect(notificaciones.emitir).toHaveBeenCalledWith(
      expect.objectContaining({
        canal: 'ventas',
        severidad: 'error',
        ruta: '/ventas?venta=4',
      }),
    );
  });

  it.each([
    [EstadoSunat.ACEPTADO, BadRequestException],
    [EstadoSunat.RECHAZADO, BadRequestException],
  ])('no reenvía un comprobante en estado %d', async (estado, excepcion) => {
    model.comprobante.mockResolvedValue(comprobante(estado));
    await expect(logic.enviar(9, 3)).rejects.toBeInstanceOf(excepcion);
    expect(apisPeru.enviarFactura).not.toHaveBeenCalled();
  });

  it('no envía dos veces a la vez', async () => {
    model.comprobante.mockResolvedValue(comprobante(EstadoSunat.PENDIENTE));
    model.reservarEnvio.mockResolvedValue(false);
    await expect(logic.enviar(9, 3)).rejects.toBeInstanceOf(ConflictException);
    expect(apisPeru.enviarFactura).not.toHaveBeenCalled();
  });
});
