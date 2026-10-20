/**
 * Formato ESC/POS del ticket. Es el mismo que usa el front para imprimir por QZ
 * (front-sistema-inga/src/modules/impresion/utils/comanda.ts): el PDF archivado
 * debe verse igual que el papel, así que cualquier cambio se hace en ambos.
 */

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
    nombre_tipo: string;
    numero: string;
    receptor_num_doc?: string | null;
    receptor_razon_social?: string | null;
    monto_gravado: number;
    monto_igv: number;
    monto_total: number;
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

/** Columnas de papel de 58 mm con la fuente normal. */
const ANCHO = 32;
const SEPARADOR = '-'.repeat(ANCHO);

// Comandos ESC/POS.
const INICIO = '\x1b@';
const IZQUIERDA = '\x1ba\x00';
const CENTRO = '\x1ba\x01';
const NEGRITA = '\x1bE\x01';
const NORMAL_PESO = '\x1bE\x00';
const tamano = (ancho: number, alto: number) =>
  `\x1d!${String.fromCharCode(((ancho - 1) << 4) | (alto - 1))}`;
const NORMAL = tamano(1, 1);
const CORTE = '\n\n\n\n\x1dV\x00';

/** Inicializa la impresora y centra, para que el logo raster salga centrado. */
export const ENCABEZADO_LOGO = INICIO + CENTRO;

/** Parte el texto en líneas de `ancho` columnas sin cortar palabras (salvo las muy largas). */
function envolver(valor: string, ancho = ANCHO): string[] {
  const lineas: string[] = [];
  for (const parrafo of valor.split('\n')) {
    let actual = '';
    for (const palabra of parrafo.split(/\s+/).filter(Boolean)) {
      for (let resto = palabra; resto;) {
        const libre = actual ? ancho - actual.length - 1 : ancho;
        if (resto.length <= libre) {
          actual = actual ? `${actual} ${resto}` : resto;
          resto = '';
        } else if (actual) {
          lineas.push(actual);
          actual = '';
        } else {
          lineas.push(resto.slice(0, ancho));
          resto = resto.slice(ancho);
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
  return envolver(texto(valor), ANCHO - prefijo.length).map(
    (linea, i) => (i ? ' '.repeat(prefijo.length) : prefijo) + linea,
  );
}

/** El tamaño más grande que entra en una línea (hasta 3x). */
function grande(valor: string, maximo = 3): string {
  const escala = [3, 2].find((n) => n <= maximo && valor.length * n <= ANCHO);
  return (escala ? tamano(escala, escala) : tamano(1, 2)) + valor + NORMAL;
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
  const producto = ANCHO - cant - subtotal;
  const sangria = ' '.repeat(cant);
  const encabezado =
    'CANT'.padEnd(cant) +
    (conSubtotal
      ? 'PRODUCTO'.padEnd(producto) + 'SUBTOTAL'.padStart(subtotal)
      : 'PRODUCTO');
  return [
    NEGRITA + encabezado + NORMAL_PESO,
    SEPARADOR,
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
  `${etiqueta}  ${soles(valor)}`.padStart(ANCHO);

export function formatearComanda(
  comanda: ComandaImpresion,
  empresa?: EmpresaTicket | null,
): string {
  if (comanda.tipo === 'COMPROBANTE')
    return formatearComprobante(comanda, empresa);
  if (comanda.tipo === 'PRECUENTA') return formatearPrecuenta(comanda);
  const lineas = [
    NEGRITA + texto(comanda.estacion).toUpperCase(),
    ...(comanda.reimpresion ? ['*** REIMPRESION ***'] : []),
    '',
    // La mesa es lo primero que busca cocina: va con el número lo más grande posible.
    ...(comanda.mesa
      ? [tamano(1, 2) + 'MESA' + NORMAL, grande(texto(comanda.mesa))]
      : [grande(destino(comanda), 2)]),
    NORMAL_PESO + IZQUIERDA + SEPARADOR,
    ...dato('Comanda', `${texto(comanda.id)} / Lote ${comanda.numero}`),
    ...dato('Fecha', fecha(comanda.fecha)),
    ...dato('Pedido', comanda.pedido),
    ...(comanda.mozo ? dato('Mozo', comanda.mozo) : []),
    SEPARADOR,
    ...tabla(comanda.items, false, (item) => [
      ...(item.adicionales ?? []).map((a) => `+ ${texto(a.nombre)}`),
      ...(item.observacion ? [`NOTA: ${texto(item.observacion)}`] : []),
    ]),
    SEPARADOR,
    ...(comanda.observacion
      ? [...envolver(`OBS: ${texto(comanda.observacion)}`), SEPARADOR]
      : []),
  ];
  return INICIO + CENTRO + lineas.join('\n') + CORTE;
}

function formatearPrecuenta(comanda: ComandaImpresion): string {
  const lineas = [
    NEGRITA + tamano(1, 2) + 'PRECUENTA' + NORMAL + NORMAL_PESO,
    'No valido como comprobante de pago',
    ...(comanda.reimpresion ? ['*** REIMPRESION ***'] : []),
    IZQUIERDA + SEPARADOR,
    ...dato('Mesa', destino(comanda)),
    ...dato('Pedido', comanda.pedido),
    ...(comanda.mozo ? dato('Mozo', comanda.mozo) : []),
    ...dato('Fecha', fecha(comanda.fecha)),
    SEPARADOR,
    ...tabla(comanda.items, true, (item) =>
      (item.adicionales ?? []).map((a) => `+ ${texto(a.nombre)}`),
    ),
    SEPARADOR,
    NEGRITA +
      tamano(1, 2) +
      importe('TOTAL', comanda.total) +
      NORMAL +
      NORMAL_PESO,
  ];
  return INICIO + CENTRO + lineas.join('\n') + CORTE;
}

/** Ticket del comprobante emitido (Ventas → Imprimir). Todavía no hay envío a SUNAT, por eso no lleva QR. */
function formatearComprobante(
  comanda: ComandaImpresion,
  empresa?: EmpresaTicket | null,
): string {
  const c = comanda.comprobante;
  const numero = texto(c?.numero);
  const documento = texto(c?.receptor_num_doc);
  const lineas = [
    NEGRITA + texto(c?.nombre_tipo).toUpperCase(),
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
    IZQUIERDA + SEPARADOR,
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
    SEPARADOR,
    ...tabla(comanda.items, true, () => []),
    SEPARADOR,
    importe('OP. GRAVADA', c?.monto_gravado),
    importe('IGV', c?.monto_igv),
    NEGRITA +
      tamano(1, 2) +
      importe('TOTAL', c?.monto_total ?? comanda.total) +
      NORMAL +
      NORMAL_PESO,
    ...((comanda.pagos ?? []).length
      ? [
          SEPARADOR,
          ...(comanda.pagos ?? []).map((p) =>
            importe(texto(p.nombre_medio), p.monto),
          ),
        ]
      : []),
    SEPARADOR,
    CENTRO + 'Gracias por su preferencia',
  ];
  return INICIO + CENTRO + lineas.join('\n') + CORTE;
}
