import { Module } from '@nestjs/common';
import { TiposProductoController } from './controllers/tipos-producto.controller';
import { TiposProductoLogic } from './logic/tipos-producto.logic';
import { TiposProductoModel } from './models/tipos-producto.model';

@Module({
  controllers: [TiposProductoController],
  providers: [TiposProductoLogic, TiposProductoModel],
})
export class TiposProductoModule {}
