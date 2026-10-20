/** Logo ya convertido a JPEG (sharp); el PDF lo incrusta tal cual (DCTDecode). */
export type ImagenTicket = { jpeg: Uint8Array; ancho: number; alto: number };

type Tramo = { texto: string; negrita: boolean; ancho: number; alto: number };
type Linea = { tramos: Tramo[]; alineacion: number };

const MM = 72 / 25.4;
/** Mismo papel de 58 mm y 32 columnas que la ticketera (ver ticket-formato.ts). */
const PAPEL = 58 * MM;
const MARGEN = 3 * MM;
const COLUMNAS = 32;
// Courier mide 0,6 em por carácter: así entran exactamente 32 columnas.
const FUENTE = (PAPEL - 2 * MARGEN) / (COLUMNAS * 0.6);
const INTERLINEA = FUENTE * 1.25;
/** El logo está en puntos de impresora térmica (203 ppp). */
const PUNTO = 72 / 203;

/** Interpreta los comandos ESC/POS que genera comanda.ts: alineación, negrita, tamaño y corte. */
export function lineasEscPos(data: string): Linea[] {
  const inicial = { negrita: false, ancho: 1, alto: 1, alineacion: 0 };
  let estado = { ...inicial };
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
      } else if (data[i + 1] === 'E') {
        estado.negrita = (n & 1) === 1;
        i += 2;
      } else i += 1;
    } else if (c === '\x1d') {
      if (data[i + 1] === 'V') break; // Corte de papel: fin del ticket.
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
): Buffer {
  const lineas = lineasEscPos(data);
  const altoLinea = (linea: Linea) =>
    INTERLINEA * Math.max(1, ...linea.tramos.map((t) => t.alto));
  const util = PAPEL - 2 * MARGEN;
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
