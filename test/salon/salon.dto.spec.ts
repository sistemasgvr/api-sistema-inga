import { BadRequestException, ValidationPipe } from '@nestjs/common';
import {
  CreateMesaDto,
  CreateSalonDto,
  FiltroSalonDto,
  UpdateMesaDto,
  UpdateSalonDto,
} from '../../src/modules/salon/dto/salon.dto';

describe('Validación HTTP de Ambientes', () => {
  const pipe = new ValidationPipe({
    transform: true,
    whitelist: true,
    forbidNonWhitelisted: true,
  });
  const salon = { id_sucursal: 1, codigo: ' SAL-01 ', nombre: ' Principal ' };
  const mesa = { id_salon: 1, codigo: 'M01', capacidad_personas: 4 };

  it('normaliza textos y permite crear un salón sin geometría explícita', async () => {
    const dto = (await pipe.transform(salon, {
      type: 'body',
      metatype: CreateSalonDto,
    })) as CreateSalonDto;
    expect(dto.codigo).toBe('SAL-01');
    expect(dto.nombre).toBe('Principal');
  });

  it.each([
    { nombre: '   ' },
    { id_sucursal: -1 },
    { ancho: 0 },
    { alto: 149 },
    { posicion_x: -1 },
    { posicion_y: 10001 },
    { posicion_x: 1.123 },
  ])('rechaza salón inválido: %j', async (patch) => {
    await expect(
      pipe.transform(
        { ...salon, ...patch },
        { type: 'body', metatype: CreateSalonDto },
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it.each([0, -1, 1.5, 101])(
    'rechaza capacidad %s',
    async (capacidad_personas) => {
      await expect(
        pipe.transform(
          { ...mesa, capacidad_personas },
          { type: 'body', metatype: CreateMesaDto },
        ),
      ).rejects.toBeInstanceOf(BadRequestException);
    },
  );

  it('rechaza un estado fuera del catálogo', async () => {
    await expect(
      pipe.transform(
        { ...mesa, estado_mesa: 5 },
        { type: 'body', metatype: CreateMesaDto },
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rechaza auditoría suplantada y campos no permitidos', async () => {
    await expect(
      pipe.transform(
        { ...mesa, id_usuario_creacion: 99 },
        { type: 'body', metatype: CreateMesaDto },
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('acepta actualizar únicamente la geometría', async () => {
    const dto = (await pipe.transform(
      { posicion_x: 30, ancho: 450 },
      { type: 'body', metatype: UpdateSalonDto },
    )) as UpdateSalonDto;
    expect(dto.posicion_x).toBe(30);
    expect(dto.nombre).toBeUndefined();
  });

  it('no permite borrar la capacidad con null', async () => {
    await expect(
      pipe.transform(
        { capacidad_personas: null },
        { type: 'body', metatype: UpdateMesaDto },
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('transforma los filtros de query string', async () => {
    const dto = (await pipe.transform(
      { id_sucursal: '2', pagina: '3', limite: '20', estado: 'todos' },
      { type: 'query', metatype: FiltroSalonDto },
    )) as FiltroSalonDto;
    expect(dto.id_sucursal).toBe(2);
    expect(dto.offset).toBe(40);
  });
});
