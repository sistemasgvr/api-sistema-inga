import { ImpresionModel } from './models/impresion.model';
import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { LoginModule } from '../login/login.module';
import { EmpresaModule } from '../empresa/empresa.module';
import { ImpresionController } from './controllers/impresion.controller';
import { ImpresionGateway } from './gateways/impresion.gateway';
import { ImpresionLogic } from './logic/impresion.logic';
import { QzSigningLogic } from './logic/qz-signing.logic';
import { TicketPdfLogic } from './logic/ticket-pdf.logic';
import { TicketPdfModel } from './models/ticket-pdf.model';

@Module({
  imports: [DatabaseModule, LoginModule, EmpresaModule],
  controllers: [ImpresionController],
  providers: [
    ImpresionModel,
    ImpresionLogic,
    ImpresionGateway,
    QzSigningLogic,
    TicketPdfModel,
    TicketPdfLogic,
  ],
  exports: [ImpresionGateway, TicketPdfLogic],
})
export class ImpresionModule {}
