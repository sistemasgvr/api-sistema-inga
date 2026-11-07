import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import {
  CreateTipoProductoDto,
  UpdatePermisosTipoProductoDto,
} from './tipos-producto.dto';

const valid = {
  nombre: '  Plato nuevo  ',
  permite_venta: true,
  requiere_receta: true,
  requiere_estacion: false,
  permite_stock_inicial: false,
};

describe('CreateTipoProductoDto', () => {
  it('normaliza nombre y acepta indicadores independientes', async () => {
    const dto = plainToInstance(CreateTipoProductoDto, valid);
    expect(dto.nombre).toBe('Plato nuevo');
    expect(await validate(dto)).toHaveLength(0);
  });
  it('rechaza nombres vacíos, indicadores ausentes y cadenas como booleanos', async () => {
    for (const input of [
      { ...valid, nombre: '  ' },
      { ...valid, permite_venta: 'false' },
      { ...valid, requiere_receta: undefined },
      { ...valid, nombre: 'a'.repeat(151) },
    ]) {
      expect(
        (await validate(plainToInstance(CreateTipoProductoDto, input))).length,
      ).toBeGreaterThan(0);
    }
  });
});

describe('UpdatePermisosTipoProductoDto', () => {
  const permisos = {
    permite_venta: true,
    requiere_receta: false,
    requiere_estacion: true,
    permite_stock_inicial: true,
  };
  it('acepta los cuatro indicadores sin exigir nombre', async () => {
    const dto = plainToInstance(UpdatePermisosTipoProductoDto, permisos);
    expect(await validate(dto)).toHaveLength(0);
  });
  it('rechaza indicadores ausentes o que no sean booleanos', async () => {
    for (const input of [
      { ...permisos, permite_venta: 'true' },
      { ...permisos, requiere_estacion: undefined },
    ]) {
      expect(
        (await validate(plainToInstance(UpdatePermisosTipoProductoDto, input)))
          .length,
      ).toBeGreaterThan(0);
    }
  });
});
