const UNIDADES = [
  '',
  'UNO',
  'DOS',
  'TRES',
  'CUATRO',
  'CINCO',
  'SEIS',
  'SIETE',
  'OCHO',
  'NUEVE',
  'DIEZ',
  'ONCE',
  'DOCE',
  'TRECE',
  'CATORCE',
  'QUINCE',
  'DIECISEIS',
  'DIECISIETE',
  'DIECIOCHO',
  'DIECINUEVE',
  'VEINTE',
  'VEINTIUNO',
  'VEINTIDOS',
  'VEINTITRES',
  'VEINTICUATRO',
  'VEINTICINCO',
  'VEINTISEIS',
  'VEINTISIETE',
  'VEINTIOCHO',
  'VEINTINUEVE',
];
const DECENAS = [
  '',
  '',
  '',
  'TREINTA',
  'CUARENTA',
  'CINCUENTA',
  'SESENTA',
  'SETENTA',
  'OCHENTA',
  'NOVENTA',
];
const CENTENAS = [
  '',
  'CIENTO',
  'DOSCIENTOS',
  'TRESCIENTOS',
  'CUATROCIENTOS',
  'QUINIENTOS',
  'SEISCIENTOS',
  'SETECIENTOS',
  'OCHOCIENTOS',
  'NOVECIENTOS',
];

/** 0..999 en letras («UNO» al final; la apócope «UN» la aplica quien llama). */
function hastaMil(n: number): string {
  if (n === 100) return 'CIEN';
  const centena = Math.floor(n / 100);
  const resto = n % 100;
  let decenas = '';
  if (resto < 30) decenas = UNIDADES[resto];
  else {
    const unidad = resto % 10;
    decenas =
      DECENAS[Math.floor(resto / 10)] +
      (unidad ? ` Y ${UNIDADES[unidad]}` : '');
  }
  return [CENTENAS[centena], decenas].filter(Boolean).join(' ');
}

/** Delante de MIL / MILLONES «UNO» se apocopa: «VEINTIUN MIL», «UN MILLON». */
const apocope = (texto: string) =>
  texto.replace(/VEINTIUNO$/, 'VEINTIUN').replace(/UNO$/, 'UN');

export function numeroEnLetras(n: number): string {
  const entero = Math.floor(Math.abs(n));
  if (entero === 0) return 'CERO';
  const millones = Math.floor(entero / 1_000_000);
  const miles = Math.floor((entero % 1_000_000) / 1000);
  const resto = entero % 1000;
  const partes: string[] = [];
  if (millones)
    partes.push(
      millones === 1
        ? 'UN MILLON'
        : `${apocope(numeroEnLetras(millones))} MILLONES`,
    );
  if (miles)
    partes.push(miles === 1 ? 'MIL' : `${apocope(hastaMil(miles))} MIL`);
  if (resto) partes.push(hastaMil(resto));
  return partes.join(' ');
}

/** Leyenda 1000 de SUNAT: «SON CIENTO DIECIOCHO CON 50/100 SOLES». */
export function montoEnLetras(monto: number): string {
  const centimos = Math.round(Math.abs(monto) * 100);
  const entero = Math.floor(centimos / 100);
  const decimales = String(centimos % 100).padStart(2, '0');
  return `SON ${numeroEnLetras(entero)} CON ${decimales}/100 SOLES`;
}
