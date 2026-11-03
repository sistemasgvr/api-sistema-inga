import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { PedidosController } from './controllers/pedidos.controller';
import { PedidoLogic } from './logic/pedido.logic';
import { PedidoModel } from './models/pedido.model';
import { ImpresionModule } from '../impresion/impresion.module';
import { NotificacionesModule } from '../notificaciones/notificaciones.module';
import { PersonasModule } from '../personas/personas.module';

@Module({
  imports: [
    DatabaseModule,
    ImpresionModule,
    NotificacionesModule,
    PersonasModule,
  ],
  controllers: [PedidosController],
  providers: [PedidoLogic, PedidoModel],
})
export class PedidosModule {}
