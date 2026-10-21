import { Body, Controller, INestApplication, Post } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { HttpExceptionFilter } from '../filters/http-exception.filter';
import { CreateMovimientoDto } from '../../modules/turnos/dto/turnos.dto';
import { crearValidationPipe } from './validacion.pipe';

@Controller('prueba')
class PruebaController {
  @Post('movimiento')
  movimiento(@Body() dto: CreateMovimientoDto) {
    return dto;
  }

  @Post('desborde')
  desborde() {
    // Lo que lanza pg cuando un NUMERIC no alcanza.
    throw Object.assign(new Error('numeric field overflow'), { code: '22003' });
  }
}

describe('Validación HTTP en español', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const modulo = await Test.createTestingModule({
      controllers: [PruebaController],
    }).compile();
    app = modulo.createNestApplication({ logger: false });
    app.useGlobalPipes(crearValidationPipe());
    app.useGlobalFilters(new HttpExceptionFilter());
    await app.init();
  });

  afterAll(() => app.close());

  it('un monto de 12 cifras responde 400 con el tope, no "Error interno"', async () => {
    const res = await request(app.getHttpServer())
      .post('/prueba/movimiento')
      .send({ tipo_movimiento: 1, monto: 999999999999, motivo: 'Hielo' });

    expect(res.status).toBe(400);
    expect(res.body.message).toBe(
      'Monto no puede ser mayor a S/ 9,999,999.00.',
    );
  });

  it('un campo no permitido se explica en español', async () => {
    const res = await request(app.getHttpServer())
      .post('/prueba/movimiento')
      .send({ tipo_movimiento: 1, monto: 5, motivo: 'Hielo', extra: 1 });

    expect(res.status).toBe(400);
    expect(res.body.message).toBe('El campo «extra» no está permitido.');
  });

  it('un desborde numérico de la BD responde 400 y no 500', async () => {
    const res = await request(app.getHttpServer()).post('/prueba/desborde');

    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/supera el máximo permitido/);
  });
});
