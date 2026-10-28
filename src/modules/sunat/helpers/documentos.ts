/**
 * Arma los JSON de APIsPERU (factura/boleta, resumen diario y comunicación de baja)
 * a partir de los datos guardados del comprobante. Son funciones puras: no tocan la
 * base ni la red, así se prueban sin dependencias.
 */
import { CODIGO_TIPO_DOC, EstadoItem, ZONA_LIMA } from '../constants/sunat';
import { montoEnLetras } from './monto-letras';

export interface EmisorSunat {
  ruc: string;
  razonSocial: string;
  nombreComercial: string | null;
  direccion: string | null;
  ubigeo: string | null;
  departamento: string | null;
  provincia: string | null;
  distrito: string | null;
}

export interface LineaSunat {
  idProducto: number | null;
  descripcion: string;
  cantidad: number;
  unidadSunat: string;
  tipoAfectacionIgv: string;
  tasaIgv: number;
  valorUnitario: number;
  precioUnitarioIgv: number;
  montoBaseIgv: number;
  montoIgv: number;
}

export interface ComprobanteSunat {
  id: number;
  tipoComprobante: number;
  serie: string;
  correlativo: string;
  fechaEmision: string;
  receptorTipoDoc: number | null;
  receptorNumDoc: string | null;
  receptorRazonSocial: string | null;
  receptorDireccion: string | null;
  lineas: LineaSunat[];
}

export interface TotalesSunat {
  gravadas: number;
  exoneradas: number;
  igv: number;
  valorVenta: number;
  total: number;
  tasaIgv: number;
}

const redondear = (n: number, decimales = 2) => {
  const factor = 10 ** decimales;
  return Math.round((n + Number.EPSILON) * factor) / factor;
};

/** SUNAT guarda el correlativo como número: «00000012» y «12» son el mismo comprobante. */
export const numeroSunat = (correlativo: string) => String(Number(correlativo));

export const serieNumero = (
  c: Pick<ComprobanteSunat, 'serie' | 'correlativo'>,
) => `${c.serie}-${numeroSunat(c.correlativo)}`;

/** Fecha y hora de Lima con su desfase fijo (Perú no tiene horario de verano). */
export function fechaLima(fecha: string | Date): string {
  const partes = new Intl.DateTimeFormat('en-CA', {
    timeZone: ZONA_LIMA,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  }).formatToParts(new Date(fecha));
  const p = (tipo: string) =>
    partes.find((x) => x.type === tipo)?.value ?? '00';
  const hora = p('hour') === '24' ? '00' : p('hour');
  return `${p('year')}-${p('month')}-${p('day')}T${hora}:${p('minute')}:${p('second')}-05:00`;
}

/** «YYYY-MM-DD» (Lima). */
export const diaLima = (fecha: string | Date) => fechaLima(fecha).slice(0, 10);

/** Fecha del día a medianoche de Lima, como la esperan los resúmenes y bajas. */
export const inicioDia = (dia: string) => `${dia}T00:00:00-05:00`;

/** Las cortesías (importe 0) no se informan: SUNAT exigiría tratarlas como transferencia gratuita. */
const lineasConImporte = (lineas: LineaSunat[]) =>
  lineas.filter((l) => l.montoBaseIgv + l.montoIgv > 0);

export function totales(lineas: LineaSunat[]): TotalesSunat {
  const conImporte = lineasConImporte(lineas);
  const suma = (
    filtro: (l: LineaSunat) => boolean,
    valor: (l: LineaSunat) => number,
  ) => redondear(conImporte.filter(filtro).reduce((s, l) => s + valor(l), 0));
  const gravadas = suma(
    (l) => l.tipoAfectacionIgv === '10',
    (l) => l.montoBaseIgv,
  );
  const exoneradas = suma(
    (l) => l.tipoAfectacionIgv === '20',
    (l) => l.montoBaseIgv,
  );
  const igv = suma(
    () => true,
    (l) => l.montoIgv,
  );
  const valorVenta = redondear(gravadas + exoneradas);
  return {
    gravadas,
    exoneradas,
    igv,
    valorVenta,
    total: redondear(valorVenta + igv),
    tasaIgv: conImporte.find((l) => l.tipoAfectacionIgv === '10')?.tasaIgv ?? 0,
  };
}

function empresa(emisor: EmisorSunat) {
  return {
    ruc: emisor.ruc,
    razonSocial: emisor.razonSocial,
    nombreComercial: emisor.nombreComercial || emisor.razonSocial,
    address: {
      ubigueo: emisor.ubigeo ?? '',
      codigoPais: 'PE',
      departamento: emisor.departamento ?? '',
      provincia: emisor.provincia ?? '',
      distrito: emisor.distrito ?? '',
      urbanizacion: '-',
      direccion: emisor.direccion ?? '',
      codLocal: '0000',
    },
  };
}

/** Faltantes que SUNAT rechazaría: mejor avisar antes de enviar. */
export function validarEmisor(emisor: EmisorSunat): string[] {
  const faltan: string[] = [];
  if (!/^\d{11}$/.test(emisor.ruc ?? '')) faltan.push('RUC');
  if (!emisor.razonSocial?.trim()) faltan.push('razón social');
  if (!emisor.direccion?.trim()) faltan.push('dirección');
  if (!/^\d{6}$/.test(emisor.ubigeo ?? '')) faltan.push('distrito con ubigeo');
  return faltan;
}

/** Catálogo 06 del receptor. La boleta sin documento va a «Clientes varios» (DNI 00000000). */
export function receptor(c: ComprobanteSunat) {
  const numero = (c.receptorNumDoc ?? '').trim() || '00000000';
  const tipo = c.receptorTipoDoc ?? (c.tipoComprobante === 2 ? 6 : 1);
  return {
    tipoDoc: String(tipo),
    numDoc: numero,
    rznSocial: (c.receptorRazonSocial ?? '').trim() || 'CLIENTES VARIOS',
  };
}

/** Cuerpo del envío, el XML y el PDF A4 de boleta/factura. */
export function construirFactura(c: ComprobanteSunat, emisor: EmisorSunat) {
  const lineas = lineasConImporte(c.lineas);
  if (!lineas.length)
    throw new Error(
      'El comprobante no tiene líneas con importe para informar a SUNAT',
    );
  const t = totales(lineas);
  const cliente = receptor(c);
  return {
    ublVersion: '2.1',
    tipoOperacion: '0101',
    tipoDoc: CODIGO_TIPO_DOC[c.tipoComprobante],
    serie: c.serie,
    correlativo: numeroSunat(c.correlativo),
    fechaEmision: fechaLima(c.fechaEmision),
    formaPago: { moneda: 'PEN', tipo: 'Contado' },
    tipoMoneda: 'PEN',
    client: {
      ...cliente,
      ...(c.receptorDireccion?.trim()
        ? { address: { direccion: c.receptorDireccion.trim() } }
        : {}),
    },
    company: empresa(emisor),
    mtoOperGravadas: t.gravadas,
    ...(t.exoneradas ? { mtoOperExoneradas: t.exoneradas } : {}),
    mtoIGV: t.igv,
    totalImpuestos: t.igv,
    valorVenta: t.valorVenta,
    subTotal: t.total,
    mtoImpVenta: t.total,
    details: lineas.map((l) => ({
      codProducto: l.idProducto ? `P${l.idProducto}` : 'P0',
      unidad: l.unidadSunat || 'NIU',
      descripcion: l.descripcion.slice(0, 500),
      cantidad: l.cantidad,
      mtoValorUnitario: l.valorUnitario,
      mtoValorVenta: l.montoBaseIgv,
      mtoBaseIgv: l.montoBaseIgv,
      porcentajeIgv: l.tipoAfectacionIgv === '10' ? l.tasaIgv : 0,
      igv: l.montoIgv,
      tipAfeIgv: l.tipoAfectacionIgv,
      totalImpuestos: l.montoIgv,
      mtoPrecioUnitario: l.precioUnitarioIgv,
    })),
    legends: [{ code: '1000', value: montoEnLetras(t.total) }],
  };
}

export interface ItemLote {
  comprobante: ComprobanteSunat;
  estadoItem: EstadoItem;
  motivo?: string | null;
}

/** Identificador del lote: RC-20261028-1 / RA-20261028-1. */
export const identificadorLote = (
  prefijo: 'RC' | 'RA',
  fechaEnvio: string,
  correlativo: number,
) => `${prefijo}-${fechaEnvio.replace(/-/g, '')}-${correlativo}`;

/** Resumen diario de boletas: adicionar (1) o anular (3). */
export function construirResumen(
  items: ItemLote[],
  emisor: EmisorSunat,
  fechaDocumentos: string,
  fechaEnvio: string,
  correlativo: number,
) {
  return {
    correlativo: String(correlativo).padStart(3, '0'),
    fecGeneracion: inicioDia(fechaDocumentos),
    fecResumen: inicioDia(fechaEnvio),
    moneda: 'PEN',
    company: empresa(emisor),
    details: items.map(({ comprobante: c, estadoItem }) => {
      const t = totales(c.lineas);
      const cliente = receptor(c);
      return {
        tipoDoc: CODIGO_TIPO_DOC[c.tipoComprobante],
        serieNro: serieNumero(c),
        estado: String(estadoItem),
        clienteTipo: cliente.tipoDoc,
        clienteNro: cliente.numDoc,
        total: t.total,
        mtoOperGravadas: t.gravadas,
        mtoOperInafectas: 0,
        mtoOperExoneradas: t.exoneradas,
        mtoOtrosCargos: 0,
        mtoIGV: t.igv,
        ...(t.tasaIgv ? { porcentajeIgv: t.tasaIgv } : {}),
      };
    }),
  };
}

/** Comunicación de baja de facturas. */
export function construirBaja(
  items: ItemLote[],
  emisor: EmisorSunat,
  fechaDocumentos: string,
  fechaEnvio: string,
  correlativo: number,
) {
  return {
    correlativo: String(correlativo).padStart(3, '0'),
    fecGeneracion: inicioDia(fechaDocumentos),
    fecComunicacion: inicioDia(fechaEnvio),
    company: empresa(emisor),
    details: items.map(({ comprobante: c, motivo }) => ({
      tipoDoc: CODIGO_TIPO_DOC[c.tipoComprobante],
      serie: c.serie,
      correlativo: numeroSunat(c.correlativo),
      desMotivoBaja: (motivo || 'ANULACION DE LA OPERACION')
        .slice(0, 100)
        .toUpperCase(),
    })),
  };
}

/**
 * Texto del QR de la representación impresa (RS 097-2012/SUNAT):
 * RUC | TIPO | SERIE | NUMERO | IGV | TOTAL | FECHA | TIPO DOC ADQ | NUM DOC ADQ | [HASH |]
 */
export function textoQr(datos: {
  ruc: string;
  tipoComprobante: number;
  serie: string;
  correlativo: string;
  igv: number;
  total: number;
  fecha: string;
  receptorTipoDoc: number | null;
  receptorNumDoc: string | null;
  hash?: string | null;
}): string {
  const campos = [
    datos.ruc,
    CODIGO_TIPO_DOC[datos.tipoComprobante],
    datos.serie,
    numeroSunat(datos.correlativo),
    Number(datos.igv ?? 0).toFixed(2),
    Number(datos.total ?? 0).toFixed(2),
    datos.fecha,
    String(datos.receptorTipoDoc ?? (datos.tipoComprobante === 2 ? 6 : 1)),
    (datos.receptorNumDoc ?? '').trim() || '00000000',
    ...(datos.hash ? [datos.hash] : []),
  ];
  return `${campos.join('|')}|`;
}
