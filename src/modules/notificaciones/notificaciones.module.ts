import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { LoginModule } from '../login/login.module';
import { NotificacionesController } from './controllers/notificaciones.controller';
import { NotificacionesLogic } from './logic/notificaciones.logic';
import { NotificacionesGateway } from './gateways/notificaciones.gateway';
import { NotificacionesModel } from './models/notificaciones.model';

@Module({
  imports: [DatabaseModule, LoginModule],
  controllers: [NotificacionesController],
  providers: [NotificacionesModel, NotificacionesLogic, NotificacionesGateway],
  exports: [NotificacionesModel, NotificacionesLogic, NotificacionesGateway],
})
export class NotificacionesModule {}
