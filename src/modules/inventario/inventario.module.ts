import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { NotificacionesModule } from '../notificaciones/notificaciones.module';
import { InventarioController } from './controllers/inventario.controller';
import { InventarioLogic } from './logic/inventario.logic';
import { InventarioModel } from './models/inventario.model';
@Module({
  imports: [DatabaseModule, NotificacionesModule],
  controllers: [InventarioController],
  providers: [InventarioLogic, InventarioModel],
})
export class InventarioModule {}
