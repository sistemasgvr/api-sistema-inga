import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { ImpresionModule } from '../impresion/impresion.module';
import { VentasController } from './controllers/ventas.controller';
import { VentasLogic } from './logic/ventas.logic';
import { VentasModel } from './models/ventas.model';

@Module({
  imports: [DatabaseModule, ImpresionModule],
  controllers: [VentasController],
  providers: [VentasLogic, VentasModel],
})
export class VentasModule {}
