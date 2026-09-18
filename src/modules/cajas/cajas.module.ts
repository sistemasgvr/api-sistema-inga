import { Module } from '@nestjs/common';
import { CajasController } from './controllers/cajas.controller';
import { CajasLogic } from './logic/cajas.logic';
import { CajasModel } from './models/cajas.model';

@Module({
  controllers: [CajasController],
  providers: [CajasLogic, CajasModel],
  exports: [CajasLogic],
})
export class CajasModule {}
