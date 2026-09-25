import { BadRequestException, NotFoundException } from '@nestjs/common';
import { SalonModel } from '../../src/modules/salon/models/salon.model';
import { SalonLogic } from '../../src/modules/salon/logic/salon.logic';

describe('Respuestas de Ambientes', () => {
  const model = { guardar: jest.fn(), estado: jest.fn(), obtener: jest.fn() };
  const logic = new SalonLogic(model as unknown as SalonModel);

  it('expone como 400 el rechazo de una mesa con atención en curso', async () => {
    model.guardar.mockResolvedValue({
      error: 'La mesa tiene atención en curso',
    });
    await expect(
      logic.guardar('mesa', 1, { capacidad_personas: 2 }, 7),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('responde 404 para registros inexistentes', async () => {
    model.obtener.mockResolvedValue({ registro: null });
    await expect(logic.obtener('salon', 999)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('no oculta las restricciones de baja lógica', async () => {
    model.estado.mockResolvedValue({
      error: 'Desactive primero las mesas del salón',
    });
    await expect(logic.estado('salon', 1, 0, 7)).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });
});
