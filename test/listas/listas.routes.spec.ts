import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { ListasController } from '../../src/modules/listas/controllers/listas.controller';
import { ListasLogic } from '../../src/modules/listas/logic/listas.logic';

describe('Contrato HTTP de listas para los selectores', () => {
  let app: INestApplication;
  const logic = { listar: jest.fn(), obtenerOpciones: jest.fn() };

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [ListasController],
      providers: [{ provide: ListasLogic, useValue: logic }],
    }).compile();
    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ transform: true, whitelist: true }));
    await app.init();
  });
  afterAll(async () => { await app.close(); });
  beforeEach(() => jest.resetAllMocks());

  it('interpreta /9/opciones como id_lista y conserva el objeto con opciones', async () => {
    const lista = { id: 9, codigo: 'MESA_ESTADO', opciones: [{ id: 1, valor_entero: 1, nombre: 'Libre' }] };
    logic.obtenerOpciones.mockResolvedValue(lista);
    const response = await request(app.getHttpServer()).get('/general/listas/9/opciones').expect(200);
    expect(logic.obtenerOpciones).toHaveBeenCalledWith(9);
    expect(response.body).toEqual(lista);
  });

  it('rechaza códigos en la ruta numérica', async () => {
    await request(app.getHttpServer()).get('/general/listas/MESA_ESTADO/opciones').expect(400);
    expect(logic.obtenerOpciones).not.toHaveBeenCalled();
  });
});
