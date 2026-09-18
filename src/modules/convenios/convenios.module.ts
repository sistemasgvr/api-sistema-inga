import { Module } from '@nestjs/common';
import { ConveniosController } from './controllers/convenios.controller';
import { ConveniosLogic } from './logic/convenios.logic';
import { ConveniosModel } from './models/convenios.model';

/**
 * Exporto ConveniosLogic porque Cuentas por Cobrar (M14) va a necesitar leer
 * convenios sin volver a pasar por HTTP.
 */
@Module({
  controllers: [ConveniosController],
  providers: [ConveniosLogic, ConveniosModel],
  exports: [ConveniosLogic],
})
export class ConveniosModule {}
