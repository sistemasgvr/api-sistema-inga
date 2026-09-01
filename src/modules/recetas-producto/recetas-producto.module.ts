import { Module } from '@nestjs/common';
import { RecetasProductoController } from './controllers/recetas-producto.controller';
import { RecetasProductoLogic } from './logic/recetas-producto.logic';
import { RecetasProductoModel } from './models/recetas-producto.model';

@Module({
  controllers: [RecetasProductoController],
  providers: [RecetasProductoLogic, RecetasProductoModel],
  exports: [RecetasProductoLogic],
})
export class RecetasProductoModule {}