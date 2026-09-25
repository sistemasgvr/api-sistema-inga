import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { SalonesController } from './controllers/salones.controller';
import { MesasController } from './controllers/mesas.controller';
import { SalonLogic } from './logic/salon.logic';
import { SalonModel } from './models/salon.model';

@Module({
  imports: [DatabaseModule],
  controllers: [SalonesController, MesasController],
  providers: [SalonLogic, SalonModel],
})
export class SalonModule {}
