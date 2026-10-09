import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  InventarioModel,
  OperacionInventario,
} from '../models/inventario.model';
import { mapSingleResult } from '../../../common/helpers/auth-response.helper';
import { FiltroInventarioDto, DisponibilidadDto, CocinaFiltroDto, AvisosCocinaFiltroDto } from '../dto/inventario.dto';

@Injectable()
export class InventarioLogic {
  constructor(private readonly model: InventarioModel) {}

  async ejecutar(
    funcion: OperacionInventario,
    datos: object | number,
    usuario: number,
  ) {
    try {
      return mapSingleResult(
        await this.model.ejecutar(funcion, datos, usuario),
        'Registro no encontrado',
      );
    } catch (error: unknown) {
      const db = error as { code?: string; message?: string };
      if (db.code === 'P0002') throw new NotFoundException(db.message);
      if (['23505', '40001', '40P01'].includes(db.code ?? ''))
        throw new ConflictException(
          'Código ya utilizado o cambio concurrente. Consulte el registro antes de reintentar.',
        );
      if (db.code === 'P0001') throw new BadRequestException(db.message);
      if (['23503', '23514', '23502', '22003', '22P02'].includes(db.code ?? ''))
        throw new BadRequestException('Datos de inventario inválidos.');
      throw error;
    }
  }

  async disponibilidad(f: DisponibilidadDto) {
    try { return mapSingleResult(await this.model.disponibilidad(f), 'Receta no encontrada'); }
    catch(e) { const error=e as {code?:string;message?:string};
      if(error.code==='P0001') throw new BadRequestException(error.message);
      if(error.code==='P0002') throw new NotFoundException(error.message);
      throw e;
    }
  }
  productosPreparables(sucursal:number) { return this.model.productosPreparables(sucursal); }
  cocina(f: CocinaFiltroDto) { return this.model.cocina(f); }
  avisos(f: AvisosCocinaFiltroDto) { return this.model.avisos(f); }
  async atenderAviso(id: number, usuario: number) {
    try { return mapSingleResult(await this.model.atenderAviso(id, usuario), 'Aviso no encontrado'); }
    catch(e) { const error=e as {code?:string;message?:string};
      if(error.code==='P0002') throw new NotFoundException(error.message);
      throw e;
    }
  }
  listar(tipo: 'stock' | 'kardex', filtros: FiltroInventarioDto) {
    return this.model.listar(tipo, filtros);
  }

  async movimiento(id: number) {
    const result = await this.model.obtener(id);
    if (!result.registro)
      throw new NotFoundException('Movimiento no encontrado');
    return result;
  }
}
