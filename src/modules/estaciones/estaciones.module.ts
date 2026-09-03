import { Module } from '@nestjs/common';
import { EstacionesController } from './controllers/estaciones.controller';
import { EstacionesLogic } from './logic/estaciones.logic';
import { EstacionesModel } from './models/estaciones.model';

@Module({
  controllers: [EstacionesController],
  providers: [EstacionesLogic, EstacionesModel],
  exports: [EstacionesLogic],
})
export class EstacionesModule {}