import type { ValidationError } from 'class-validator';

/**
 * Traduce los errores de class-validator a español, con el nombre del campo y
 * el límite que se incumplió. Los mensajes propios de cada DTO (ya en español)
 * se respetan tal cual; solo se traducen los mensajes por defecto en inglés.
 */

const PALABRAS: Record<string, string> = {
  anio: 'año',
  codigo: 'código',
  condicion: 'condición',
  denominacion: 'denominación',
  descripcion: 'descripción',
  direccion: 'dirección',
  estacion: 'estación',
  limite: 'límite',
  numero: 'número',
  num: 'número',
  observacion: 'observación',
  opcion: 'opción',
  pagina: 'página',
  posicion: 'posición',
  preparacion: 'preparación',
  razon: 'razón',
  salon: 'salón',
  sustitucion: 'sustitución',
  telefono: 'teléfono',
  titulo: 'título',
  busqueda: 'búsqueda',
  credito: 'crédito',
  categoria: 'categoría',
  subcategoria: 'subcategoría',
  ip: 'IP',
  ruc: 'RUC',
  igv: 'IGV',
  url: 'URL',
  pin: 'PIN',
  kds: 'KDS',
};

const ETIQUETAS: Record<string, string> = {
  email: 'Correo electrónico',
  password: 'Contraseña',
  username: 'Usuario',
  nombres: 'Nombres',
  apellido_paterno: 'Apellido paterno',
  apellido_materno: 'Apellido materno',
  numero_documento: 'Número de documento',
  razon_social: 'Razón social',
  comensales: 'Comensales',
  num_comensales: 'Número de comensales',
  monto_apertura: 'Monto de apertura',
  monto_cierre_declarado: 'Monto contado al cierre',
  limite_credito: 'Límite de crédito',
  precio_venta: 'Precio de venta',
  precio_unitario: 'Precio unitario',
  precio_referencial: 'Precio referencial',
  precio_adicional: 'Precio del adicional',
  costo_unitario: 'Costo unitario',
  costo_inicial: 'Costo inicial',
  stock_inicial: 'Stock inicial',
  stock_minimo: 'Stock mínimo',
  sueldo_referencial: 'Sueldo referencial',
  cantidad_insumo: 'Cantidad de insumo',
  cantidad_entregada: 'Cantidad entregada',
  cantidad_cancelada: 'Cantidad cancelada',
  porcentaje_merma: 'Porcentaje de merma',
  rendimiento_porciones: 'Rendimiento en porciones',
  tiempo_preparacion: 'Tiempo de preparación',
};

/** "monto_apertura" → "Monto de apertura"; "id_caja" → "Caja". */
export function etiquetaCampo(propiedad: string): string {
  if (ETIQUETAS[propiedad]) return ETIQUETAS[propiedad];
  const palabras = propiedad
    .split('_')
    .filter(Boolean)
    .filter(
      (palabra, i, lista) => !(palabra === 'id' && i === 0 && lista.length > 1),
    )
    .map((palabra) => PALABRAS[palabra] ?? palabra);
  const texto = palabras.join(' ') || propiedad;
  return texto.charAt(0).toUpperCase() + texto.slice(1);
}

export function formatearNumero(valor: number, decimales = 0): string {
  return valor.toLocaleString('en-US', {
    minimumFractionDigits: decimales,
    maximumFractionDigits: Math.max(decimales, 4),
  });
}

const ES_DINERO =
  /(monto|precio|costo|sueldo|limite_credito|denominacion|importe|total)/;

function numeroEn(mensaje: string): number | null {
  const match = mensaje.match(/(-?\d+(?:\.\d+)?)(?!.*\d)/);
  return match ? Number(match[1]) : null;
}

type Traductor = (campo: string, mensaje: string, propiedad: string) => string;

const TRADUCCIONES: Record<string, Traductor> = {
  isNotEmpty: (c) => `${c} es obligatorio.`,
  isDefined: (c) => `${c} es obligatorio.`,
  arrayNotEmpty: (c) => `${c} debe tener al menos un elemento.`,
  isString: (c) => `${c} debe ser un texto.`,
  isInt: (c) => `${c} debe ser un número entero, sin decimales.`,
  isNumber: (c, _m, p) =>
    ES_DINERO.test(p)
      ? `${c} debe ser un monto válido, con hasta 2 decimales.`
      : `${c} debe ser un número válido.`,
  isPositive: (c) => `${c} debe ser mayor a cero.`,
  isBoolean: (c) => `${c} debe ser sí o no.`,
  isDateString: (c) => `${c} debe ser una fecha válida.`,
  isEmail: (c) => `${c} debe ser un correo electrónico válido.`,
  isIp: (c) => `${c} debe ser una dirección IP válida.`,
  isUuid: (c) => `${c} debe ser un identificador válido.`,
  isArray: (c) => `${c} debe ser una lista.`,
  isObject: (c) => `${c} tiene un formato inválido.`,
  isIn: (c) => `${c} tiene un valor no permitido.`,
  matches: (c) => `${c} no tiene el formato correcto.`,
  arrayUnique: (c) => `${c} no debe tener elementos repetidos.`,
  nestedValidation: (c) => `${c} tiene un formato inválido.`,
  maxLength: (c, m) => `${c} admite como máximo ${numeroEn(m)} caracteres.`,
  minLength: (c, m) => `${c} debe tener al menos ${numeroEn(m)} caracteres.`,
  isLength: (c, m) => {
    const [min, max] = (m.match(/\d+/g) ?? []).map(Number);
    return `${c} debe tener entre ${min} y ${max} caracteres.`;
  },
  arrayMaxSize: (c, m) => `${c} admite como máximo ${numeroEn(m)} elementos.`,
  arrayMinSize: (c, m) => `${c} debe tener al menos ${numeroEn(m)} elementos.`,
  min: (c, m, p) => {
    const limite = numeroEn(m) ?? 0;
    return ES_DINERO.test(p)
      ? `${c} debe ser como mínimo S/ ${formatearNumero(limite, 2)}.`
      : `${c} debe ser como mínimo ${formatearNumero(limite)}.`;
  },
  max: (c, m, p) => {
    const limite = numeroEn(m) ?? 0;
    return ES_DINERO.test(p)
      ? `${c} no puede ser mayor a S/ ${formatearNumero(limite, 2)}.`
      : `${c} no puede ser mayor a ${formatearNumero(limite)}.`;
  },
};

/** Los mensajes por defecto de class-validator empiezan con el nombre del campo. */
function esMensajePorDefecto(mensaje: string, propiedad: string): boolean {
  const sinEach = mensaje.replace(/^each value in /, '');
  return (
    sinEach.startsWith(`${propiedad} `) ||
    sinEach.startsWith(`nested property ${propiedad} `) ||
    sinEach.startsWith(`All ${propiedad}'s elements`) ||
    sinEach.startsWith(`property ${propiedad} `)
  );
}

function traducirRestriccion(
  clave: string,
  mensaje: string,
  propiedad: string,
  campo: string,
): string {
  if (clave === 'whitelistValidation') {
    return `El campo «${propiedad}» no está permitido.`;
  }
  if (!esMensajePorDefecto(mensaje, propiedad)) {
    // Los topes (MontoMaximo...) ya traen la etiqueta; se le suma la fila.
    const etiqueta = etiquetaCampo(propiedad);
    return campo !== etiqueta && mensaje.startsWith(`${etiqueta} `)
      ? campo + mensaje.slice(etiqueta.length)
      : mensaje;
  }
  const traductor = TRADUCCIONES[clave];
  return traductor
    ? traductor(campo, mensaje, propiedad)
    : `${campo} tiene un valor inválido.`;
}

export function traducirErroresValidacion(
  errores: ValidationError[],
  ruta: string[] = [],
): string[] {
  const mensajes: string[] = [];

  for (const error of errores) {
    const esIndice = /^\d+$/.test(error.property);
    const rutaActual = [...ruta, error.property];
    let campo = esIndice
      ? `Fila ${Number(error.property) + 1}`
      : etiquetaCampo(error.property);
    // En listas anidadas indico la fila: "Cantidad (fila 2)".
    const fila = [...ruta].reverse().find((parte) => /^\d+$/.test(parte));
    if (!esIndice && fila !== undefined)
      campo = `${campo} (fila ${Number(fila) + 1})`;

    for (const [clave, mensaje] of Object.entries(error.constraints ?? {})) {
      mensajes.push(traducirRestriccion(clave, mensaje, error.property, campo));
    }

    if (error.children?.length) {
      mensajes.push(...traducirErroresValidacion(error.children, rutaActual));
    }
  }

  return [...new Set(mensajes)];
}
