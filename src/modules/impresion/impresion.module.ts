import { ImpresionModel } from './models/impresion.model';
import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { LoginModule } from '../login/login.module';
import { ImpresionController } from './controllers/impresion.controller';
import { ImpresionGateway } from './gateways/impresion.gateway';
import { ImpresionLogic } from './logic/impresion.logic';
import { QzSigningLogic } from './logic/qz-signing.logic';

@Module({
  imports: [DatabaseModule, LoginModule],
  controllers: [ImpresionController],
  providers: [ImpresionModel, ImpresionLogic, ImpresionGateway, QzSigningLogic],
  exports: [ImpresionGateway],
})
export class ImpresionModule {}
