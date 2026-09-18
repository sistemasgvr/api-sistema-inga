import { Module } from '@nestjs/common';
import { CuentasPorPagarController } from './controllers/cuentas-por-pagar.controller';
import { CuentasPorPagarLogic } from './logic/cuentas-por-pagar.logic';
import { CuentasPorPagarModel } from './models/cuentas-por-pagar.model';

/**
 * Exporto la lógica porque dos módulos la van a necesitar:
 *   M14 Gastos Diarios → registrar el cargo automático cuando un ítem se marca
 *                        como "a crédito"
 *   M02 Dashboard      → la alerta de "Deudas por pagar" que pidió el cliente
 */
@Module({
  controllers: [CuentasPorPagarController],
  providers: [CuentasPorPagarLogic, CuentasPorPagarModel],
  exports: [CuentasPorPagarLogic],
})
export class CuentasPorPagarModule {}
