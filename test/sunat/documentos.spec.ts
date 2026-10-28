import { EstadoItem } from '../../src/modules/sunat/constants/sunat';
import {
  construirBaja,
  construirFactura,
  construirResumen,
  fechaLima,
  textoQr,
  totales,
  validarEmisor,
  type ComprobanteSunat,
  type EmisorSunat,
  type LineaSunat,
} from '../../src/modules/sunat/helpers/documentos';
import {
  montoEnLetras,
  numeroEnLetras,
} from '../../src/modules/sunat/helpers/monto-letras';

const emisor: EmisorSunat = {
  ruc: '20123456789',
  razonSocial: 'RESTAURANTE INGA S.A.C.',
  nombreComercial: 'INGA',
  direccion: 'Av. Principal 123',
  ubigeo: '150122',
  departamento: 'LIMA',
  provincia: 'LIMA',
  distrito: 'MIRAFLORES',
};

// Mismo cálculo que ven_comprobante_insertar_detalle: precio con IGV incluido (afecto_igv).
const linea = (total: number, cantidad = 1, tasa = 18): LineaSunat => {
  const base = Math.round((total / (1 + tasa / 100)) * 100) / 100;
  return {
    idProducto: 7,
    descripcion: 'Arroz con pato',
    cantidad,
    unidadSunat: 'NIU',
    tipoAfectacionIgv: tasa ? '10' : '20',
    tasaIgv: tasa,
    valorUnitario: base / cantidad,
    precioUnitarioIgv: total / cantidad,
    montoBaseIgv: base,
    montoIgv: Math.round((total - base) * 100) / 100,
  };
};

const boleta: ComprobanteSunat = {
  id: 1,
  tipoComprobante: 1,
  serie: 'B001',
  correlativo: '00000012',
  fechaEmision: '2026-10-28T03:30:00Z', // 27/10 22:30 en Lima
  receptorTipoDoc: 1,
  receptorNumDoc: '00000000',
  receptorRazonSocial: 'CLIENTES VARIOS',
  receptorDireccion: null,
  lineas: [
    linea(41.5, 2),
    linea(10),
    { ...linea(0), montoBaseIgv: 0, montoIgv: 0 },
  ],
};

describe('Monto en letras (leyenda 1000)', () => {
  it.each([
    [0, 'CERO'],
    [1, 'UNO'],
    [16, 'DIECISEIS'],
    [21, 'VEINTIUNO'],
    [100, 'CIEN'],
    [118, 'CIENTO DIECIOCHO'],
    [1000, 'MIL'],
    [21_000, 'VEINTIUN MIL'],
    [31_500, 'TREINTA Y UN MIL QUINIENTOS'],
    [1_000_000, 'UN MILLON'],
    [
      2_345_678,
      'DOS MILLONES TRESCIENTOS CUARENTA Y CINCO MIL SEISCIENTOS SETENTA Y OCHO',
    ],
  ])('%d → %s', (n, letras) => expect(numeroEnLetras(n)).toBe(letras));

  it('agrega céntimos y moneda', () => {
    expect(montoEnLetras(118)).toBe('SON CIENTO DIECIOCHO CON 00/100 SOLES');
    expect(montoEnLetras(51.5)).toBe('SON CINCUENTA Y UNO CON 50/100 SOLES');
  });
});

describe('JSON de APIsPERU', () => {
  it('usa la hora de Lima con su desfase', () => {
    expect(fechaLima('2026-10-28T03:30:00Z')).toBe('2026-10-27T22:30:00-05:00');
  });

  it('arma la boleta con totales cuadrados y sin las cortesías', () => {
    const doc = construirFactura(boleta, emisor);
    expect(doc).toMatchObject({
      tipoDoc: '03',
      serie: 'B001',
      correlativo: '12',
      fechaEmision: '2026-10-27T22:30:00-05:00',
      tipoMoneda: 'PEN',
      client: {
        tipoDoc: '1',
        numDoc: '00000000',
        rznSocial: 'CLIENTES VARIOS',
      },
      company: {
        ruc: '20123456789',
        address: { ubigueo: '150122', codLocal: '0000' },
      },
      mtoImpVenta: 51.5,
      legends: [
        { code: '1000', value: 'SON CINCUENTA Y UNO CON 50/100 SOLES' },
      ],
    });
    expect(doc.details).toHaveLength(2);
    expect(doc.mtoOperGravadas + doc.mtoIGV).toBeCloseTo(doc.mtoImpVenta, 2);
    const suma = doc.details.reduce((s, d) => s + d.mtoValorVenta + d.igv, 0);
    expect(suma).toBeCloseTo(doc.mtoImpVenta, 2);
    expect(doc.details[0]).toMatchObject({
      cantidad: 2,
      tipAfeIgv: '10',
      porcentajeIgv: 18,
      mtoPrecioUnitario: 20.75,
    });
  });

  it('informa la tasa 0 como operación exonerada', () => {
    const t = totales([linea(20, 1, 0)]);
    expect(t).toMatchObject({ gravadas: 0, exoneradas: 20, igv: 0, total: 20 });
  });

  it('rechaza un comprobante sin importe', () => {
    expect(() =>
      construirFactura(
        { ...boleta, lineas: [{ ...linea(0), montoBaseIgv: 0, montoIgv: 0 }] },
        emisor,
      ),
    ).toThrow(/líneas con importe/);
  });

  it('detecta los datos de empresa que SUNAT exige', () => {
    expect(validarEmisor(emisor)).toEqual([]);
    expect(validarEmisor({ ...emisor, ubigeo: null, direccion: '' })).toEqual([
      'dirección',
      'distrito con ubigeo',
    ]);
  });

  it('arma el resumen diario con el estado de cada boleta', () => {
    const r = construirResumen(
      [
        { comprobante: boleta, estadoItem: EstadoItem.ADICIONAR },
        {
          comprobante: { ...boleta, correlativo: '13' },
          estadoItem: EstadoItem.ANULAR,
        },
      ],
      emisor,
      '2026-10-27',
      '2026-10-28',
      2,
    );
    expect(r).toMatchObject({
      correlativo: '002',
      fecGeneracion: '2026-10-27T00:00:00-05:00',
      fecResumen: '2026-10-28T00:00:00-05:00',
      moneda: 'PEN',
    });
    expect(r.details.map((d) => [d.serieNro, d.estado, d.total])).toEqual([
      ['B001-12', '1', 51.5],
      ['B001-13', '3', 51.5],
    ]);
  });

  it('arma la comunicación de baja de facturas', () => {
    const factura = {
      ...boleta,
      tipoComprobante: 2,
      serie: 'F001',
      correlativo: '00000005',
    };
    const b = construirBaja(
      [
        {
          comprobante: factura,
          estadoItem: EstadoItem.ANULAR,
          motivo: 'error en ruc',
        },
      ],
      emisor,
      '2026-10-27',
      '2026-10-28',
      1,
    );
    expect(b.details).toEqual([
      {
        tipoDoc: '01',
        serie: 'F001',
        correlativo: '5',
        desMotivoBaja: 'ERROR EN RUC',
      },
    ]);
    expect(b.fecComunicacion).toBe('2026-10-28T00:00:00-05:00');
  });

  it('arma el texto del QR de SUNAT', () => {
    expect(
      textoQr({
        ruc: '20123456789',
        tipoComprobante: 2,
        serie: 'F001',
        correlativo: '00000005',
        igv: 6.33,
        total: 41.5,
        fecha: '2026-10-27',
        receptorTipoDoc: 6,
        receptorNumDoc: '20555555555',
        hash: 'abc=',
      }),
    ).toBe('20123456789|01|F001|5|6.33|41.50|2026-10-27|6|20555555555|abc=|');
  });
});
