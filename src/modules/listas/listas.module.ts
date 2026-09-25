import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { ListasController } from './controllers/listas.controller';
import { ListasLogic } from './logic/listas.logic';
import { ListasModel } from './models/listas.model';

@Module({
  imports: [DatabaseModule],
  controllers: [ListasController],
  providers: [ListasLogic, ListasModel],
})
export class ListasModule {}
