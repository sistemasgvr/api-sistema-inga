import { Module } from '@nestjs/common';
import { AdicionalesProductoController } from './controllers/adicionales-producto.controller';
import { AdicionalesProductoLogic } from './logic/adicionales-producto.logic';
import { AdicionalesProductoModel } from './models/adicionales-producto.model';

@Module({
  controllers: [AdicionalesProductoController],
  providers: [AdicionalesProductoLogic, AdicionalesProductoModel],
  exports: [AdicionalesProductoLogic],
})
export class AdicionalesProductoModule {}