import { ValidationPipe } from '@nestjs/common';
import {
  AbrirPedidoDto,
  AgregarItemDto,
  AnularPedidoDto,
  EditarItemDto,
  EstadoPedidoDto,
} from '../../src/modules/pedidos/dto/pedido.dto';

describe('Validación de solicitudes de pedidos', () => {
  const pipe = new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
  });
  const parse = (metatype: new () => object, value: object) =>
    pipe.transform(value, { type: 'body', metatype });

  it.each([0, -1, 0.00001, '1', null])(
    'rechaza cantidad inválida %p',
    async (cantidad) => {
      await expect(
        parse(AgregarItemDto, { id_producto: 1, cantidad }),
      ).rejects.toThrow();
    },
  );
  it('rechaza precio con más de dos decimales y adicionales duplicados', async () => {
    await expect(
      parse(AgregarItemDto, {
        id_producto: 1,
        cantidad: 1,
        precio_unitario: 1.001,
      }),
    ).rejects.toThrow();
    await expect(
      parse(AgregarItemDto, {
        id_producto: 1,
        cantidad: 1,
        adicionales: [{ id_adicional: 1 }, { id_adicional: 1 }],
      }),
    ).rejects.toThrow();
  });
  it('no acepta actor, estado o impuesto enviados por el cliente', async () => {
    await expect(
      parse(AbrirPedidoDto, {
        tipo_pedido: 1,
        id_mesa: 1,
        id_mozo: 2,
        id_turno: 1,
        tasa_igv: 0,
      }),
    ).rejects.toThrow();
    await expect(
      parse(EditarItemDto, { cantidad: 2, stock_descontado: false }),
    ).rejects.toThrow();
  });
  it('exige autor y motivo para anular', async () => {
    await expect(parse(AnularPedidoDto, { motivo: 'Error' })).rejects.toThrow();
    await expect(
      parse(AnularPedidoDto, { id_usuario_autoriza: 2, motivo: '' }),
    ).rejects.toThrow();
  });
  it('no permite volver a ABIERTO por el endpoint de estados', async () => {
    await expect(
      parse(EstadoPedidoDto, { estado_pedido: 1 }),
    ).rejects.toThrow();
  });
  it('acepta adicionales y selecciones de receta válidos', async () => {
    await expect(
      parse(AgregarItemDto, {
        id_producto: 1,
        cantidad: 1.25,
        adicionales: [{ id_adicional: 2 }],
        insumos_seleccionados: [3],
      }),
    ).resolves.toBeInstanceOf(AgregarItemDto);
  });
});
