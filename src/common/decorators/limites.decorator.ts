import { Max } from 'class-validator';
import {
  CANTIDAD_BILLETES_MAXIMA,
  CANTIDAD_MAXIMA,
  MONTO_MAXIMO,
} from '../constants/limites';
import {
  etiquetaCampo,
  formatearNumero,
} from '../helpers/validacion-mensajes.helper';

/** Tope de dinero (S/ 9,999,999.00) con mensaje en español. */
export const MontoMaximo = () =>
  Max(MONTO_MAXIMO, {
    message: ({ property }) =>
      `${etiquetaCampo(property)} no puede ser mayor a S/ ${formatearNumero(MONTO_MAXIMO, 2)}.`,
  });

/** Tope de cantidades (unidades, porciones, comensales, stock). */
export const CantidadMaxima = (maximo = CANTIDAD_MAXIMA) =>
  Max(maximo, {
    message: ({ property }) =>
      `${etiquetaCampo(property)} no puede ser mayor a ${formatearNumero(maximo)}.`,
  });

export const CantidadBilletesMaxima = () =>
  CantidadMaxima(CANTIDAD_BILLETES_MAXIMA);
