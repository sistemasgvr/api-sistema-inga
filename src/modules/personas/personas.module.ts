import { Module } from '@nestjs/common';
import { PersonasController } from './controllers/personas.controller';
import { PersonasLogic } from './logic/personas.logic';
import { PersonasModel } from './models/personas.model';

/**
 * Exporto PersonasLogic porque tres módulos que vienen después lo van a usar
 * directamente, sin dar la vuelta por HTTP:
 *   M07 Compras  → validar que el proveedor elegido tenga es_proveedor = true
 *   M12 Cobros   → validar cliente y convenio antes de cobrar a crédito
 *   M14 CxC      → resolver el nombre de la persona en los reportes
 */
@Module({
  controllers: [PersonasController],
  providers: [PersonasLogic, PersonasModel],
  exports: [PersonasLogic],
})
export class PersonasModule {}
