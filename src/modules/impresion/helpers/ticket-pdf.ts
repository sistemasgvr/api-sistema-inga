import QRCode from 'qrcode';
import { COLUMNAS, type AnchoPapel } from './ticket-formato';

/** Logo ya convertido a JPEG (sharp); el PDF lo incrusta tal cual (DCTDecode). */
export type ImagenTicket = { jpeg: Uint8Array; ancho: number; alto: number };

type Tramo = { texto: string; negrita: boolean; ancho: number; alto: number };
/** `qr`: renglón con el QR que imprimió GS ( k (datos y puntos por módulo). */
type Linea = {
  tramos: Tramo[];
  alineacion: number;
  qr?: { datos: string; modulo: number };
};

/** Matriz del QR (corrección M, como la ticketera) con 4 módulos de margen. */
function matrizQr(datos: string) {
  const { modules } = QRCode.create(datos, { errorCorrectionLevel: 'M' });
  return {
    tamano: modules.size,
    oscuro: (f: number, c: number) => Boolean(modules.get(f, c)),
  };
}
const MARGEN_QR = 4;

const MM = 72 / 25.4;
const MARGEN = 3 * MM;

/** Mismo rollo y columnas que la ticketera (ver COLUMNAS en ticket-formato.ts). */
function medidas(papel: AnchoPapel) {
  const ancho = papel * MM;
  // Courier mide 0,6 em por carácter: así entran exactamente las columnas del rollo.
  const fuente =
    (ancho - 2 * MARGEN) / ((COLUMNAS[papel] ?? COLUMNAS[80]) * 0.6);
  return { ancho, fuente, interlinea: fuente * 1.25 };
}
/** El logo está en puntos de impresora térmica (203 ppp). */
const PUNTO = 72 / 203;

/** Interpreta los comandos ESC/POS que genera comanda.ts: alineación, negrita, tamaño y corte. */
export function lineasEscPos(data: string): Linea[] {
  const inicial = { negrita: false, ancho: 1, alto: 1, alineacion: 0 };
  let estado = { ...inicial };
  let qr = { datos: '', modulo: 3 };
  const lineas: Linea[] = [];
  let actual: Linea = { tramos: [], alineacion: 0 };
  const cerrar = () => {
    if (!actual.tramos.length) actual.alineacion = estado.alineacion;
    lineas.push(actual);
    actual = { tramos: [], alineacion: 0 };
  };
  for (let i = 0; i < data.length; i++) {
    const c = data[i];
    const n = data.charCodeAt(i + 2);
    if (c === '\x1b') {
      if (data[i + 1] === '@') {
        estado = { ...inicial };
        i += 1;
      } else if (data[i + 1] === 'a') {
        estado.alineacion = n % 48;
        i += 2;
      } else if (data[i + 1] === 'd') {
        i += 2; // Avance de papel al final (tira sin corte): no se dibuja.
      } else if (data[i + 1] === 'E') {
        estado.negrita = (n & 1) === 1;
        i += 2;
      } else i += 1;
    } else if (c === '\x1d') {
      if (data[i + 1] === 'V') break; // Corte de papel: fin del ticket.
      if (data[i + 1] === '(' && data[i + 2] === 'k') {
        // GS ( k pL pH cn fn …: tamaño del módulo (67), datos (80) e impresión (81) del QR.
        const largo = data.charCodeAt(i + 3) + data.charCodeAt(i + 4) * 256;
        const fn = data.charCodeAt(i + 6);
        if (fn === 67) qr.modulo = data.charCodeAt(i + 7) || qr.modulo;
        else if (fn === 80) qr.datos = data.substr(i + 8, largo - 3);
        else if (fn === 81 && qr.datos) {
          if (actual.tramos.length) cerrar();
          lineas.push({ tramos: [], alineacion: estado.alineacion, qr });
          qr = { datos: '', modulo: qr.modulo };
        }
        i += 4 + largo;
        continue;
      }
      if (data[i + 1] === '!') {
        estado.ancho = (n >> 4) + 1;
        estado.alto = (n & 15) + 1;
        i += 2;
      } else i += 1;
    } else if (c === '\n') {
      cerrar();
    } else if (c >= ' ' && c <= '~') {
      // En ESC/POS la alineación vigente al empezar a escribir la línea es la que se aplica.
      if (!actual.tramos.length) actual.alineacion = estado.alineacion;
      const ultimo = actual.tramos[actual.tramos.length - 1];
      if (
        ultimo &&
        ultimo.negrita === estado.negrita &&
        ultimo.ancho === estado.ancho &&
        ultimo.alto === estado.alto
      )
        ultimo.texto += c;
      else
        actual.tramos.push({
          texto: c,
          negrita: estado.negrita,
          ancho: estado.ancho,
          alto: estado.alto,
        });
    }
  }
  if (actual.tramos.length) cerrar();
  while (
    lineas.length &&
    !lineas[lineas.length - 1].qr &&
    !lineas[lineas.length - 1].tramos.some((t) => t.texto.trim())
  )
    lineas.pop();
  return lineas;
}

const cadena = (valor: string) =>
  `(${valor.replace(/[\\()]/g, (c) => `\\${c}`)})`;
const num = (valor: number) => Number(valor.toFixed(2)).toString();

/** PDF de una sola página con el ancho del papel térmico y el alto justo del ticket. */
export function ticketPdf(
  data: string,
  logo?: ImagenTicket | null,
  titulo = 'Ticket',
  papel: AnchoPapel = 80,
): Buffer {
  const {
    ancho: PAPEL,
    fuente: FUENTE,
    interlinea: INTERLINEA,
  } = medidas(papel);
  const lineas = lineasEscPos(data);
  const util = PAPEL - 2 * MARGEN;
  // QR: cada módulo mide lo mismo que en la térmica (puntos a 203 ppp), sin pasarse del rollo.
  const qrs = new Map(
    lineas
      .filter((l) => l.qr)
      .map((l) => {
        const matriz = matrizQr(l.qr!.datos);
        const modulo = Math.min(
          l.qr!.modulo * PUNTO,
          util / (matriz.tamano + 2 * MARGEN_QR),
        );
        return [l, { ...matriz, modulo }] as const;
      }),
  );
  const altoLinea = (linea: Linea) => {
    const qr = qrs.get(linea);
    return qr
      ? (qr.tamano + 2 * MARGEN_QR) * qr.modulo
      : INTERLINEA * Math.max(1, ...linea.tramos.map((t) => t.alto));
  };
  const escalaLogo = logo ? Math.min(PUNTO, util / logo.ancho) : 0;
  const logoAncho = logo ? logo.ancho * escalaLogo : 0;
  const logoAlto = logo ? logo.alto * escalaLogo : 0;
  const alto =
    2 * MARGEN +
    (logo ? logoAlto + INTERLINEA / 2 : 0) +
    lineas.reduce((suma, l) => suma + altoLinea(l), 0);

  const dibujo: string[] = [];
  let y = alto - MARGEN;
  if (logo) {
    dibujo.push(
      `q ${num(logoAncho)} 0 0 ${num(logoAlto)} ${num((PAPEL - logoAncho) / 2)} ${num(y - logoAlto)} cm /Im1 Do Q`,
    );
    y -= logoAlto + INTERLINEA / 2;
  }
  for (const linea of lineas) {
    const h = altoLinea(linea);
    const qr = qrs.get(linea);
    if (qr) {
      // Un rectángulo por cada tramo de módulos oscuros seguidos de la fila.
      const lado = qr.tamano * qr.modulo;
      const x0 =
        MARGEN +
        (linea.alineacion === 1
          ? (util - lado) / 2
          : linea.alineacion === 2
            ? util - lado
            : 0);
      const y0 = y - MARGEN_QR * qr.modulo;
      const rects: string[] = [];
      for (let f = 0; f < qr.tamano; f++)
        for (let c = 0; c < qr.tamano; c++) {
          if (!qr.oscuro(f, c)) continue;
          let fin = c;
          while (fin + 1 < qr.tamano && qr.oscuro(f, fin + 1)) fin++;
          rects.push(
            `${num(x0 + c * qr.modulo)} ${num(y0 - (f + 1) * qr.modulo)} ${num((fin - c + 1) * qr.modulo)} ${num(qr.modulo)} re`,
          );
          c = fin;
        }
      dibujo.push(`0 g\n${rects.join('\n')}\nf`);
      y -= h;
      continue;
    }
    // Línea base centrada en el renglón; Courier desciende ~0,22 em bajo ella.
    const k = h / INTERLINEA;
    const base = y - h + k * ((INTERLINEA - FUENTE) / 2 + FUENTE * 0.22);
    const total = linea.tramos.reduce(
      (suma, t) => suma + t.texto.length * 0.6 * FUENTE * t.ancho,
      0,
    );
    let x =
      MARGEN +
      (linea.alineacion === 1
        ? (util - total) / 2
        : linea.alineacion === 2
          ? util - total
          : 0);
    for (const t of linea.tramos) {
      // Doble ancho/alto como en la térmica: el alto agranda la fuente y Tz compensa el ancho.
      dibujo.push(
        `BT /${t.negrita ? 'F2' : 'F1'} ${num(FUENTE * t.alto)} Tf ${num((t.ancho / t.alto) * 100)} Tz ${num(x)} ${num(base)} Td ${cadena(t.texto)} Tj ET`,
      );
      x += t.texto.length * 0.6 * FUENTE * t.ancho;
    }
    y -= h;
  }

  const contenido = dibujo.join('\n');
  const recursos = `/Font << /F1 5 0 R /F2 6 0 R >>${logo ? ' /XObject << /Im1 7 0 R >>' : ''}`;
  const objetos: (string | Uint8Array)[][] = [
    ['<< /Type /Catalog /Pages 2 0 R >>'],
    ['<< /Type /Pages /Kids [3 0 R] /Count 1 >>'],
    [
      `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${num(PAPEL)} ${num(alto)}] /Resources << ${recursos} >> /Contents 4 0 R >>`,
    ],
    [`<< /Length ${contenido.length} >>\nstream\n${contenido}\nendstream`],
    [
      '<< /Type /Font /Subtype /Type1 /BaseFont /Courier /Encoding /WinAnsiEncoding >>',
    ],
    [
      '<< /Type /Font /Subtype /Type1 /BaseFont /Courier-Bold /Encoding /WinAnsiEncoding >>',
    ],
    ...(logo
      ? [
          [
            `<< /Type /XObject /Subtype /Image /Width ${logo.ancho} /Height ${logo.alto} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ${logo.jpeg.length} >>\nstream\n`,
            logo.jpeg,
            '\nendstream',
          ],
        ]
      : []),
    [
      `<< /Title ${cadena(titulo.replace(/[^\x20-\x7e]/g, ''))} /Producer (Inga) >>`,
    ],
  ];

  // Todo el texto es ASCII: un carácter equivale a un byte, así los offsets del xref son exactos.
  const partes: Uint8Array[] = [];
  let largo = 0;
  const escribir = (parte: string | Uint8Array) => {
    const bytes =
      typeof parte === 'string'
        ? Uint8Array.from(parte, (c) => c.charCodeAt(0))
        : parte;
    partes.push(bytes);
    largo += bytes.length;
  };
  escribir('%PDF-1.4\n');
  const offsets = objetos.map((partesObjeto, i) => {
    const inicio = largo;
    escribir(`${i + 1} 0 obj\n`);
    partesObjeto.forEach(escribir);
    escribir('\nendobj\n');
    return inicio;
  });
  const xref = largo;
  escribir(
    `xref\n0 ${objetos.length + 1}\n0000000000 65535 f \n${offsets.map((o) => `${String(o).padStart(10, '0')} 00000 n \n`).join('')}`,
  );
  escribir(
    `trailer\n<< /Size ${objetos.length + 1} /Root 1 0 R /Info ${objetos.length} 0 R >>\nstartxref\n${xref}\n%%EOF\n`,
  );

  return Buffer.concat(partes, largo);
}
