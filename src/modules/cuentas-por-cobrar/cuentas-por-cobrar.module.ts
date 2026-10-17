import { Module } from '@nestjs/common';
import { CuentasPorCobrarController } from './controllers/cuentas-por-cobrar.controller';
import { CuentasPorCobrarLogic } from './logic/cuentas-por-cobrar.logic';
import { CuentasPorCobrarModel } from './models/cuentas-por-cobrar.model';
import { NotificacionesModule } from '../notificaciones/notificaciones.module';

/**
 * Exporto la lógica porque dos módulos la van a necesitar:
 *   M12 Ventas    → registrar el consumo automático cuando un pedido se cobre
 *                   con medio de pago "crédito" (consorcio)
 *   M02 Dashboard → la alerta de "Por cobrar al consorcio"
 */
@Module({
  imports: [NotificacionesModule],
  controllers: [CuentasPorCobrarController],
  providers: [CuentasPorCobrarLogic, CuentasPorCobrarModel],
  exports: [CuentasPorCobrarLogic],
})
export class CuentasPorCobrarModule {}
