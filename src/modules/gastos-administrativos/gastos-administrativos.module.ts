import { Module } from '@nestjs/common';
import { GastosAdministrativosController } from './controllers/gastos-administrativos.controller';
import { GastosAdministrativosLogic } from './logic/gastos-administrativos.logic';
import { GastosAdministrativosModel } from './models/gastos-administrativos.model';

/**
 * Exporto la lógica porque el dashboard (M02) necesita el total de gastos
 * administrativos del período para calcular la rentabilidad real:
 * ventas − insumos (M14) − planilla (M17) − administrativos (este).
 */
@Module({
  controllers: [GastosAdministrativosController],
  providers: [GastosAdministrativosLogic, GastosAdministrativosModel],
  exports: [GastosAdministrativosLogic],
})
export class GastosAdministrativosModule {}
