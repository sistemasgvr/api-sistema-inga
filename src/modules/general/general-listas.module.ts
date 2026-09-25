import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { GeneralListasController } from './controllers/general-listas.controller';
import { GeneralListasLogic } from './logic/general-listas.logic';
import { GeneralListasModel } from './models/general-listas.model';

@Module({
  imports: [DatabaseModule],
  controllers: [GeneralListasController],
  providers: [GeneralListasLogic, GeneralListasModel],
  exports: [GeneralListasLogic],
})
export class GeneralListasModule {}