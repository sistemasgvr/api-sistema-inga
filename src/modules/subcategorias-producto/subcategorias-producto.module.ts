import { Module } from '@nestjs/common';
import { SubCategoriasProductoController } from './controllers/subcategorias-producto.controller';
import { SubCategoriasProductoLogic } from './logic/subcategorias-producto.logic';
import { SubCategoriasProductoModel } from './models/subcategorias-producto.model';

@Module({
  controllers: [SubCategoriasProductoController],
  providers: [SubCategoriasProductoLogic, SubCategoriasProductoModel],
  exports: [SubCategoriasProductoLogic],
})
export class SubCategoriasProductoModule {}