import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AuthenticatedUser } from '../../src/common/interfaces/authenticated-user.interface';
import { PedidoLogic } from '../../src/modules/pedidos/logic/pedido.logic';
import { PedidoModel } from '../../src/modules/pedidos/models/pedido.model';

describe('Orquestación de pedidos', () => {
  const model = { obtener: jest.fn(), ejecutar: jest.fn() };
  const logic = new PedidoLogic(
    model as unknown as PedidoModel,
    new ConfigService({ PEDIDOS_TASA_IGV: 18 }),
  );
  const user = {
    id: 7,
    permisos: ['pedidos.estado'],
    es_super_admin: false,
  } as AuthenticatedUser;
  beforeEach(() => jest.resetAllMocks());

  it.each([2, 5])(
    'impide eludir el permiso de comanda/anulación usando estado %s',
    (estado_pedido) => {
      expect(() =>
        logic.ejecutar('estado', 1, null, { estado_pedido }, user),
      ).toThrow(ForbiddenException);
      expect(model.ejecutar).not.toHaveBeenCalled();
    },
  );
  it('obtiene actor y tasa del contexto del servidor', async () => {
    model.ejecutar.mockResolvedValue({ registro: { id: 1 } });
    await logic.ejecutar(
      'abrir',
      null,
      null,
      { tipo_pedido: 1, tasa_igv: 0 },
      user,
    );
    expect(model.ejecutar).toHaveBeenCalledWith(
      'abrir',
      null,
      null,
      { tipo_pedido: 1, tasa_igv: 18 },
      7,
    );
  });
  it.each([
    ['P0001', BadRequestException],
    ['P0002', NotFoundException],
    ['42501', ForbiddenException],
    ['23505', ConflictException],
    ['40P01', ConflictException],
  ])('traduce %s a una respuesta HTTP adecuada', async (code, exception) => {
    model.obtener.mockRejectedValue({ code, message: 'Validación del pedido' });
    await expect(logic.obtener(1)).rejects.toBeInstanceOf(exception);
  });
  it('conserva errores imprevistos para el filtro y logs', async () => {
    const error = new Error('Connection error');
    model.obtener.mockRejectedValue(error);
    await expect(logic.obtener(1)).rejects.toBe(error);
  });
});
