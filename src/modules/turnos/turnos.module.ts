import { Module } from '@nestjs/common';
import { TurnosController } from './controllers/turnos.controller';
import { TurnosLogic } from './logic/turnos.logic';
import { TurnosModel } from './models/turnos.model';

/**
 * Exporto TurnosLogic porque el cobro (M12) lo va a necesitar: antes de
 * registrar un `ven_pago` tiene que confirmar que el cajero tenga un turno
 * abierto y saber contra cuál registrarlo.
 */
@Module({
  controllers: [TurnosController],
  providers: [TurnosLogic, TurnosModel],
  exports: [TurnosLogic],
})
export class TurnosModule {}
