import {
  BadRequestException,
  NotFoundException,
  ValidationPipe,
} from '@nestjs/common';
import {
  ListaCodigoParamDto,
  ListaIdParamDto,
} from '../../src/modules/listas/dto/listas.dto';
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

  it('normaliza el código estable', async () => {
    const dto = (await pipe.transform(
      { codigo: ' mesa_estado ' },
      { type: 'param', metatype: ListaCodigoParamDto },
    )) as ListaCodigoParamDto;
    expect(dto.codigo).toBe('MESA_ESTADO');
  });

  it('rechaza códigos vacíos', async () => {
    await expect(
      pipe.transform(
        { codigo: ' ' },
        { type: 'param', metatype: ListaCodigoParamDto },
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('envía ID y código como parámetros de SQL', async () => {
    const callFunctionJson = jest.fn().mockResolvedValue({ registro: null });
    const model = new ListasModel({
      callFunctionJson,
    } as unknown as DatabaseService);
    await model.obtenerOpciones(null, 'MESA_ESTADO');
    expect(callFunctionJson).toHaveBeenLastCalledWith(
      'gen_obtener_lista_opciones',
      [null, 'MESA_ESTADO'],
    );
    await model.obtenerOpciones(37, null);
    expect(callFunctionJson).toHaveBeenLastCalledWith(
      'gen_obtener_lista_opciones',
      [37, null],
    );
  });

  it('distingue lista inexistente/inactiva de lista sin opciones', async () => {
    const obtenerOpciones = jest.fn().mockResolvedValue({ registro: null });
    const logic = new ListasLogic({
      obtenerOpciones,
    } as unknown as ListasModel);
    await expect(
      logic.obtenerOpciones(null, 'NO_EXISTE'),
    ).rejects.toBeInstanceOf(NotFoundException);
    obtenerOpciones.mockResolvedValue({
      registro: { id: 37, codigo: 'MESA_ESTADO', opciones: [] },
    });
    await expect(logic.obtenerOpciones(37, null)).resolves.toEqual({
      id: 37,
      codigo: 'MESA_ESTADO',
      opciones: [],
    });
  });
});
