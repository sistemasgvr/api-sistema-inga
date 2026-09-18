import { Module } from '@nestjs/common';
import { GastosDiariosController } from './controllers/gastos-diarios.controller';
import { GastosDiariosLogic } from './logic/gastos-diarios.logic';
import { GastosDiariosModel } from './models/gastos-diarios.model';

/**
 * Exporto la lógica porque el dashboard (M02) necesita el gasto de insumos del
 * período para calcular la rentabilidad y el porcentaje de las ventas que se
 * va en insumos:
 *   ventas − insumos (este) − planilla (M17) − administrativos (M16)
 *
 * El enlace con CxP (M15) NO pasa por acá: lo resuelve la función SQL
 * `gdo_agregar_linea` llamando directamente a `cxp_registrar_cargo`, que es
 * donde vive la regla de negocio en este proyecto.
 */
@Module({
  controllers: [GastosDiariosController],
  providers: [GastosDiariosLogic, GastosDiariosModel],
  exports: [GastosDiariosLogic],
})
export class GastosDiariosModule {}
