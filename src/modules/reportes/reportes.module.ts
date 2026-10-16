import { Module } from '@nestjs/common';
import { ReportesController } from './controllers/reportes.controller';
import { ReportesLogic } from './logic/reportes.logic';
import { ReportesModel } from './models/reportes.model';

/** Dashboard gerencial y reportería por módulo (solo lectura). */
@Module({
  controllers: [ReportesController],
  providers: [ReportesLogic, ReportesModel],
})
export class ReportesModule {}
