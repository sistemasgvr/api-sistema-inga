import {
  BadRequestException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { VentasLogic } from '../../src/modules/ventas/logic/ventas.logic';
import { VentasModel } from '../../src/modules/ventas/models/ventas.model';
import { ImpresionGateway } from '../../src/modules/impresion/gateways/impresion.gateway';

describe('Ventas', () => {
  const model = {
    obtener: jest.fn(),
    reimprimirComanda: jest.fn(),
    imprimirComprobante: jest.fn(),
    cambiarMedioPago: jest.fn(),
  };
  const impresion = { notificar: jest.fn() };
  const logic = new VentasLogic(
    model as unknown as VentasModel,
    impresion as unknown as ImpresionGateway,
  );
  beforeEach(() => jest.resetAllMocks());

  it.each([
    ['reimprimirComanda', () => logic.reimprimirComanda(1, 7)],
    ['imprimirComprobante', () => logic.imprimirComprobante(1, 7)],
  ] as const)(
    '%s avisa a impresión sólo si la base confirmó el trabajo',
    async (metodo, ejecutar) => {
      model[metodo].mockResolvedValue({ registro: { id: 1 } });
      await ejecutar();
      expect(impresion.notificar).toHaveBeenCalledTimes(1);
      model[metodo].mockRejectedValue({ code: 'P0001', message: 'Sin estación' });
      await expect(ejecutar()).rejects.toBeInstanceOf(BadRequestException);
      expect(impresion.notificar).toHaveBeenCalledTimes(1);
    },
  );

  it('pasa el pago, el medio y el usuario autenticado al cambiar el medio', async () => {
    model.cambiarMedioPago.mockResolvedValue({ registro: { id: 3 } });
    await logic.cambiarMedioPago(57, 2, 15);
    expect(model.cambiarMedioPago).toHaveBeenCalledWith(57, 2, 15);
  });

  it.each([
    ['P0001', BadRequestException],
    ['P0002', NotFoundException],
    ['40P01', ConflictException],
  ])('traduce %s a una respuesta HTTP adecuada', async (code, exception) => {
    model.obtener.mockRejectedValue({ code, message: 'Validación de la venta' });
    await expect(logic.obtener(1)).rejects.toBeInstanceOf(exception);
  });

  it('devuelve 404 si la venta no existe', async () => {
    model.obtener.mockResolvedValue({ registro: null });
    await expect(logic.obtener(99)).rejects.toBeInstanceOf(NotFoundException);
  });
});
