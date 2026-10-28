/**
 * Formato ESC/POS del ticket. Es el mismo que usa el front para imprimir por QZ
 * (front-sistema-inga/src/modules/impresion/utils/comanda.ts): el PDF archivado
 * debe verse igual que el papel, así que cualquier cambio se hace en ambos.
 */

import { textoQr } from '../../sunat/helpers/documentos';

/** Ancho del rollo de la impresora térmica, en milímetros. */
export type AnchoPapel = 58 | 80;

/** Encabezado de los tickets (Configuración → Empresa). `logo`: PNG blanco y negro en base64. */
export interface EmpresaTicket {
  ruc: string | null;
  razon_social: string | null;
  direccion: string | null;
  logo: string | null;
}

/** Copia congelada del ticket (ven_impresion_trabajo.contenido o ven_ticket_comprobante). */
export interface ComandaImpresion {
  tipo?: 'PRECUENTA' | 'COMPROBANTE';
  reimpresion?: boolean;
  comprobante?: {
    /** 1 boleta, 2 factura (electrónicas: llevan QR), 3 nota de venta. */
    tipo_comprobante?: number;
    nombre_tipo: string;
    numero: string;
    receptor_tipo_doc?: number | null;
    receptor_num_doc?: string | null;
    receptor_razon_social?: string | null;
    monto_gravado: number;
    monto_exonerado?: number;
    monto_igv: number;
    monto_total: number;
    /** AAAA-MM-DD (Lima), para el QR. */
    fecha_emision?: string;
    /** Resumen de la firma; solo existe después de enviarlo a SUNAT. */
    hash?: string | null;
  };
  pagos?: { nombre_medio: string; monto: number }[];
  total?: number;
  id: string;
  numero: number;
  pedido: string;
  mesa?: string;
  mozo?: string;
  estacion: string;
  fecha: string;
  tipo_pedido: number;
  observacion?: string;
  items: {
    cantidad: number | string;
    nombre_producto: string;
    observacion?: string;
    monto_subtotal?: number;
    adicionales?: { nombre: string }[];
  }[];
}

// ASCII portable: evita seleccionar una tabla de caracteres distinta en cada impresora.
const texto = (value: string | number | null | undefined) =>
  String(value ?? '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^\x20-\x7e\n]/g, '')
    .slice(0, 2000);

const soles = (valor: unknown) => `S/ ${Number(valor ?? 0).toFixed(2)}`;

/** Columnas con la fuente normal (A, 12 puntos): 58 mm → 32, 80 mm → 48. */
export const COLUMNAS: Record<AnchoPapel, number> = { 58: 32, 80: 48 };

// Comandos ESC/POS.
const INICIO = '\x1b@';
const IZQUIERDA = '\x1ba\x00';
const CENTRO = '\x1ba\x01';
const NEGRITA = '\x1bE\x01';
const NORMAL_PESO = '\x1bE\x00';
const tamano = (ancho: number, alto: number) =>
  `\x1d!${String.fromCharCode(((ancho - 1) << 4) | (alto - 1))}`;
const NORMAL = tamano(1, 1);
// 4 renglones en blanco y corte parcial GS V 66 (la impresora avanza hasta la
// cuchilla antes de cortar). En el PDF el avance y el corte no se dibujan.
const FINAL = '\x1bd\x04\x1dVB\x00';

/** Puntos por módulo del QR: ~2 cm en el rollo de 58 mm y algo más en el de 80 mm. */
export const PUNTOS_MODULO_QR: Record<AnchoPapel, number> = { 58: 4, 80: 5 };

/**
 * QR nativo de la ticketera (GS ( k, modelo 2, corrección M): guardar datos e
 * imprimir. El PDF interpreta estos mismos comandos y dibuja el QR.
 */
export function qrEscPos(datos: string, papel: AnchoPapel = 80): string {
  const comando = (fn: number, parametros: string) => {
    const largo = parametros.length + 2;
    return `\x1d(k${String.fromCharCode(largo % 256, Math.floor(largo / 256))}1${String.fromCharCode(fn)}${parametros}`;
  };
  return (
    comando(65, '2\x00') +
    comando(67, String.fromCharCode(PUNTOS_MODULO_QR[papel] ?? 5)) +
    comando(69, '1') +
    comando(80, `0${datos}`) +
    comando(81, '0')
  );
}

const fecha = (valor: string) =>
  new Date(valor)
    .toLocaleString('es-PE', {
      timeZone: 'America/Lima',
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
    })
    .replace(',', '');

const destino = (comanda: ComandaImpresion) =>
  texto(
    comanda.mesa || (comanda.tipo_pedido === 3 ? 'DELIVERY' : 'PARA LLEVAR'),
  );

const cantidad = (valor: unknown) => String(Number(valor ?? 0));

type Item = ComandaImpresion['items'][number];

/** Herramientas de maquetación para un ancho de papel concreto. */
function maqueta(papel: AnchoPapel) {
  const ancho = COLUMNAS[papel] ?? COLUMNAS[80];
  const separador = '-'.repeat(ancho);

  /** Parte el texto en líneas de `columnas` sin cortar palabras (salvo las muy largas). */
  function envolver(valor: string, columnas = ancho): string[] {
    const lineas: string[] = [];
    for (const parrafo of valor.split('\n')) {
      let actual = '';
      for (const palabra of parrafo.split(/\s+/).filter(Boolean)) {
        for (let resto = palabra; resto;) {
          const libre = actual ? columnas - actual.length - 1 : columnas;
          if (resto.length <= libre) {
            actual = actual ? `${actual} ${resto}` : resto;
            resto = '';
          } else if (actual) {
            lineas.push(actual);
            actual = '';
          } else {
            lineas.push(resto.slice(0, columnas));
            resto = resto.slice(columnas);
          }
        }
      }
      lineas.push(actual);
    }
    return lineas.filter((linea, i) => linea || i === 0);
  }

  /** «Etiqueta: valor», con el valor alineado en una sola columna. */
  function dato(
    etiqueta: string,
    valor: string | number | null | undefined,
  ): string[] {
    const prefijo = `${etiqueta}:`.padEnd(9);
    return envolver(texto(valor), ancho - prefijo.length).map(
      (linea, i) => (i ? ' '.repeat(prefijo.length) : prefijo) + linea,
    );
  }

  /** El tamaño más grande que entra en una línea (hasta 3x). */
  function grande(valor: string, maximo = 3): string {
    const escala = [3, 2].find((n) => n <= maximo && valor.length * n <= ancho);
    return (escala ? tamano(escala, escala) : tamano(1, 2)) + valor + NORMAL;
  }

  /**
   * Tabla CANT / PRODUCTO [/ SUBTOTAL]. Los nombres largos continúan debajo,
   * alineados con la columna de producto, igual que adicionales y notas.
   */
  function tabla(
    items: Item[],
    conSubtotal: boolean,
    extras: (item: Item) => string[],
  ): string[] {
    const cant = 5;
    const subtotal = conSubtotal ? 9 : 0;
    const producto = ancho - cant - subtotal;
    const sangria = ' '.repeat(cant);
    const encabezado =
      'CANT'.padEnd(cant) +
      (conSubtotal
        ? 'PRODUCTO'.padEnd(producto) + 'SUBTOTAL'.padStart(subtotal)
        : 'PRODUCTO');
    return [
      NEGRITA + encabezado + NORMAL_PESO,
      separador,
      ...items.flatMap((item) => {
        const [primera, ...resto] = envolver(
          texto(item.nombre_producto),
          producto,
        );
        const monto = conSubtotal
          ? Number(item.monto_subtotal ?? 0)
              .toFixed(2)
              .padStart(subtotal)
          : '';
        return [
          cantidad(item.cantidad).padEnd(cant) +
            (conSubtotal ? primera.padEnd(producto) : primera) +
            monto,
          ...resto.map((linea) => sangria + linea),
          ...extras(item).flatMap((extra) =>
            envolver(extra, producto).map((linea) => sangria + linea),
          ),
        ];
      }),
    ];
  }

  /** Línea de importe alineada a la derecha. */
  const importe = (etiqueta: string, valor: unknown) =>
    `${etiqueta}  ${soles(valor)}`.padStart(ancho);

  return { separador, envolver, dato, grande, tabla, importe };
}

export function formatearComanda(
  comanda: ComandaImpresion,
  empresa?: EmpresaTicket | null,
  papel: AnchoPapel = 80,
): string {
  if (comanda.tipo === 'COMPROBANTE')
    return formatearComprobante(comanda, empresa, papel);
  if (comanda.tipo === 'PRECUENTA') return formatearPrecuenta(comanda, papel);
  const { separador, envolver, dato, grande, tabla } = maqueta(papel);
  const lineas = [
    NEGRITA + texto(comanda.estacion).toUpperCase(),
    ...(comanda.reimpresion ? ['*** REIMPRESION ***'] : []),
    '',
    // La mesa es lo primero que busca cocina: va con el número lo más grande posible.
    ...(comanda.mesa
      ? [tamano(1, 2) + 'MESA' + NORMAL, grande(texto(comanda.mesa))]
      : [grande(destino(comanda), 2)]),
    NORMAL_PESO + IZQUIERDA + separador,
    ...dato('Comanda', `${texto(comanda.id)} / Lote ${comanda.numero}`),
    ...dato('Fecha', fecha(comanda.fecha)),
    ...dato('Pedido', comanda.pedido),
    ...(comanda.mozo ? dato('Mozo', comanda.mozo) : []),
    separador,
    ...tabla(comanda.items, false, (item) => [
      ...(item.adicionales ?? []).map((a) => `+ ${texto(a.nombre)}`),
      ...(item.observacion ? [`NOTA: ${texto(item.observacion)}`] : []),
    ]),
    separador,
    ...(comanda.observacion
      ? [...envolver(`OBS: ${texto(comanda.observacion)}`), separador]
      : []),
  ];
  return INICIO + CENTRO + lineas.join('\n') + '\n' + FINAL;
}

function formatearPrecuenta(
  comanda: ComandaImpresion,
  papel: AnchoPapel,
): string {
  const { separador, dato, tabla, importe } = maqueta(papel);
  const lineas = [
    NEGRITA + tamano(1, 2) + 'PRECUENTA' + NORMAL + NORMAL_PESO,
    'No valido como comprobante de pago',
    ...(comanda.reimpresion ? ['*** REIMPRESION ***'] : []),
    IZQUIERDA + separador,
    ...dato('Mesa', destino(comanda)),
    ...dato('Pedido', comanda.pedido),
    ...(comanda.mozo ? dato('Mozo', comanda.mozo) : []),
    ...dato('Fecha', fecha(comanda.fecha)),
    separador,
    ...tabla(comanda.items, true, (item) =>
      (item.adicionales ?? []).map((a) => `+ ${texto(a.nombre)}`),
    ),
    separador,
    NEGRITA +
      tamano(1, 2) +
      importe('TOTAL', comanda.total) +
      NORMAL +
      NORMAL_PESO,
  ];
  return INICIO + CENTRO + lineas.join('\n') + '\n' + FINAL;
}

/**
 * Ticket del comprobante (cobro y Ventas → Imprimir). La boleta y la factura son
 * electrónicas: se imprimen al cobrar como representación impresa, con el QR de
 * SUNAT, aunque su envío ocurra después (dentro del plazo configurado).
 */
function formatearComprobante(
  comanda: ComandaImpresion,
  empresa: EmpresaTicket | null | undefined,
  papel: AnchoPapel,
): string {
  const { separador, envolver, dato, grande, tabla, importe } = maqueta(papel);
  const c = comanda.comprobante;
  const numero = texto(c?.numero);
  const documento = texto(c?.receptor_num_doc);
  const electronico =
    (c?.tipo_comprobante === 1 || c?.tipo_comprobante === 2) &&
    Boolean(empresa?.ruc);
  const nombreTipo =
    texto(c?.nombre_tipo).toUpperCase() + (electronico ? ' ELECTRONICA' : '');
  const qr =
    electronico && c
      ? textoQr({
          ruc: empresa!.ruc!,
          tipoComprobante: c.tipo_comprobante!,
          serie: c.numero.split('-')[0],
          correlativo: c.numero.split('-')[1] ?? '0',
          igv: c.monto_igv,
          total: c.monto_total,
          fecha: c.fecha_emision ?? comanda.fecha.slice(0, 10),
          receptorTipoDoc: c.receptor_tipo_doc ?? null,
          receptorNumDoc: c.receptor_num_doc ?? null,
          hash: c.hash,
        })
      : null;
  const lineas = [
    ...envolver(nombreTipo).map((l) => NEGRITA + l),
    grande(numero, 2) + NORMAL_PESO,
    ...(comanda.reimpresion ? ['*** REIMPRESION ***'] : []),
    '',
    ...(empresa?.razon_social
      ? envolver(texto(empresa.razon_social)).map(
          (l) => NEGRITA + l + NORMAL_PESO,
        )
      : []),
    ...(empresa?.ruc ? [`RUC ${texto(empresa.ruc)}`] : []),
    ...(empresa?.direccion ? envolver(texto(empresa.direccion)) : []),
    IZQUIERDA + separador,
    ...dato('Fecha', fecha(comanda.fecha)),
    ...dato(
      'Pedido',
      `${texto(comanda.pedido)} - ${comanda.mesa ? `Mesa ${texto(comanda.mesa)}` : destino(comanda)}`,
    ),
    ...dato('Cliente', c?.receptor_razon_social || 'CLIENTES VARIOS'),
    ...(documento && documento !== '00000000'
      ? dato(
          documento.length === 11
            ? 'RUC'
            : documento.length === 8
              ? 'DNI'
              : 'Doc',
          documento,
        )
      : []),
    separador,
    ...tabla(comanda.items, true, () => []),
    separador,
    importe('OP. GRAVADA', c?.monto_gravado),
    ...(Number(c?.monto_exonerado ?? 0) > 0
      ? [importe('OP. EXONERADA', c?.monto_exonerado)]
      : []),
    importe('IGV', c?.monto_igv),
    NEGRITA +
      tamano(1, 2) +
      importe('TOTAL', c?.monto_total ?? comanda.total) +
      NORMAL +
      NORMAL_PESO,
    ...((comanda.pagos ?? []).length
      ? [
          separador,
          ...(comanda.pagos ?? []).map((p) =>
            importe(texto(p.nombre_medio), p.monto),
          ),
        ]
      : []),
    separador,
    ...(qr
      ? [
          CENTRO + qrEscPos(qr, papel),
          ...envolver(`Representacion impresa de la ${nombreTipo}`),
          ...(c?.hash ? envolver(`Resumen: ${texto(c.hash)}`) : []),
          'Consulte en www.sunat.gob.pe',
          separador,
        ]
      : []),
    CENTRO + 'Gracias por su preferencia',
  ];
  return INICIO + CENTRO + lineas.join('\n') + '\n' + FINAL;
}
