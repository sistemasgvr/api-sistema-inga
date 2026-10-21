import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import {
  CreateMovimientoDto,
  GuardarArqueoDto,
} from '../../modules/turnos/dto/turnos.dto';
import { AbrirPedidoDto } from '../../modules/pedidos/dto/pedido.dto';
import {
  etiquetaCampo,
  traducirErroresValidacion,
} from './validacion-mensajes.helper';

async function mensajes<T extends object>(clase: new () => T, datos: object) {
  const errores = await validate(plainToInstance(clase, datos), {
    whitelist: true,
    forbidNonWhitelisted: true,
  });
  return traducirErroresValidacion(errores);
}

describe('traducirErroresValidacion', () => {
  it('rechaza montos de 12 cifras con el tope en soles', async () => {
    const r = await mensajes(CreateMovimientoDto, {
      tipo_movimiento: 1,
      monto: 999999999999,
      motivo: 'Prueba',
    });
    expect(r).toEqual(['Monto no puede ser mayor a S/ 9,999,999.00.']);
  });

  it('traduce longitudes máximas con el campo y el límite', async () => {
    const r = await mensajes(CreateMovimientoDto, {
      tipo_movimiento: 1,
      monto: 10,
      motivo: 'x'.repeat(300),
    });
    expect(r).toEqual(['Motivo admite como máximo 255 caracteres.']);
  });

  it('respeta los mensajes propios del DTO', async () => {
    const r = await mensajes(CreateMovimientoDto, {
      tipo_movimiento: 1,
      monto: 0,
      motivo: 'a',
    });
    expect(r).toEqual(['El monto debe ser mayor a cero']);
  });

  it('pide enteros para comensales', async () => {
    const r = await mensajes(AbrirPedidoDto, {
      tipo_pedido: 1,
      num_comensales: 2.5,
    });
    expect(r).toContain(
      'Número de comensales debe ser un número entero, sin decimales.',
    );
  });

  it('indica la fila en listas anidadas', async () => {
    const r = await mensajes(GuardarArqueoDto, {
      detalle: [{ denominacion: 200, cantidad: 99999999 }],
    });
    expect(r).toContain('Cantidad (fila 1) no puede ser mayor a 99,999.');
  });

  it('arma etiquetas legibles', () => {
    expect(etiquetaCampo('id_caja')).toBe('Caja');
    expect(etiquetaCampo('razon_social')).toBe('Razón social');
    expect(etiquetaCampo('descripcion')).toBe('Descripción');
  });
});
