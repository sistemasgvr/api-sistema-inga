import { Module } from '@nestjs/common';
import { PlanillaController } from './controllers/planilla.controller';
import { PlanillaLogic } from './logic/planilla.logic';
import { PlanillaModel } from './models/planilla.model';

/**
 * Exporto PlanillaLogic porque el dashboard (M02) va a necesitar el gasto de
 * planilla del período para calcular la rentabilidad y el porcentaje de las
 * ventas que consume el personal.
 */
@Module({
  controllers: [PlanillaController],
  providers: [PlanillaLogic, PlanillaModel],
  exports: [PlanillaLogic],
})
export class PlanillaModule {}
