import { BadRequestException } from '@nestjs/common';
import { TiposProductoModel } from '../models/tipos-producto.model';
import { TiposProductoLogic } from './tipos-producto.logic';

const permisos = {
  permite_venta: true,
  requiere_receta: true,
  requiere_estacion: false,
  permite_stock_inicial: false,
  idUsuarioAuditoria: 7,
};

describe('TiposProductoLogic', () => {
  const model = { actualizarPermisos: jest.fn(), impacto: jest.fn() };
  const logic = new TiposProductoLogic(model as unknown as TiposProductoModel);

  beforeEach(() => jest.resetAllMocks());

  it('actualiza permisos dentro de la empresa de la sesión', async () => {
    const registro = { id: 3, nombre: 'Platos', ...permisos };
    model.actualizarPermisos.mockResolvedValue({ registro });
    await expect(logic.actualizarPermisos(3, permisos, 2)).resolves.toBe(
      registro,
    );
    expect(model.actualizarPermisos).toHaveBeenCalledWith(3, permisos, 2);
  });

  it('propaga el error de SQL al actualizar permisos', async () => {
    model.actualizarPermisos.mockResolvedValue({
      error: 'Tipo de producto no encontrado',
      registro: null,
    });
    await expect(logic.actualizarPermisos(3, permisos, 2)).rejects.toThrow(
      BadRequestException,
    );
  });

  it('devuelve los conteos de impacto del tipo', async () => {
    const registro = { total: 4, sin_receta: 2, sin_estacion: 1, en_venta: 3 };
    model.impacto.mockResolvedValue({ registro });
    await expect(logic.impacto(3, 2)).resolves.toBe(registro);
    expect(model.impacto).toHaveBeenCalledWith(3, 2);
  });
});
