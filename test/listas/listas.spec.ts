import {
  BadRequestException,
  NotFoundException,
  ValidationPipe,
} from '@nestjs/common';
import { ListaIdParamDto } from '../../src/modules/listas/dto/listas.dto';
import { ListasLogic } from '../../src/modules/listas/logic/listas.logic';
import { ListasModel } from '../../src/modules/listas/models/listas.model';
import { DatabaseService } from '../../src/database/database.service';

describe('Catálogos compartidos', () => {
  const pipe = new ValidationPipe({
    transform: true,
    whitelist: true,
    forbidNonWhitelisted: true,
  });

  it.each(['0', '-1', '1.5', 'abc', '9007199254740992'])(
    'rechaza ID inválido %s',
    async (id) => {
      await expect(
        pipe.transform({ id }, { type: 'param', metatype: ListaIdParamDto }),
      ).rejects.toBeInstanceOf(BadRequestException);
    },
  );

  it('envía el ID de la lista como parámetro de SQL', async () => {
    const callFunctionJson = jest.fn().mockResolvedValue({ registro: null });
    const model = new ListasModel({
      callFunctionJson,
    } as unknown as DatabaseService);
    await model.obtenerOpciones(37);
    expect(callFunctionJson).toHaveBeenLastCalledWith(
      'gen_obtener_opciones_lista',
      [37],
    );
  });

  it('distingue lista inexistente/inactiva de lista sin opciones', async () => {
    const obtenerOpciones = jest.fn().mockResolvedValue({ registro: null });
    const logic = new ListasLogic({
      obtenerOpciones,
    } as unknown as ListasModel);
    await expect(logic.obtenerOpciones(999)).rejects.toBeInstanceOf(
      NotFoundException,
    );
    obtenerOpciones.mockResolvedValue({
      registro: { id: 37, codigo: 'MESA_ESTADO', opciones: [] },
    });
    await expect(logic.obtenerOpciones(37)).resolves.toEqual({
      id: 37,
      codigo: 'MESA_ESTADO',
      opciones: [],
    });
  });
});
