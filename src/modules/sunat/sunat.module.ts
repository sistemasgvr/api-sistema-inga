import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { ApisPeruModule } from '../../integrations/apisperu/apisperu.module';
import { NotificacionesModule } from '../notificaciones/notificaciones.module';
import { SunatConfiguracionController } from './controllers/sunat-configuracion.controller';
import { SunatController } from './controllers/sunat.controller';
import { SunatArchivosLogic } from './logic/sunat-archivos.logic';
import { SunatCifradoLogic } from './logic/sunat-cifrado.logic';
import { SunatConfiguracionLogic } from './logic/sunat-configuracion.logic';
import { SunatEmisionLogic } from './logic/sunat-emision.logic';
import { SunatLotesLogic } from './logic/sunat-lotes.logic';
import { SunatProgramadorLogic } from './logic/sunat-programador.logic';
import { SunatComprobantesModel } from './models/sunat-comprobantes.model';
import { SunatConfiguracionModel } from './models/sunat-configuracion.model';
import { SunatLotesModel } from './models/sunat-lotes.model';

/** Facturación electrónica (boletas y facturas) vía APIsPERU. */
@Module({
  imports: [DatabaseModule, ApisPeruModule, NotificacionesModule],
  controllers: [SunatConfiguracionController, SunatController],
  providers: [
    SunatConfiguracionModel,
    SunatComprobantesModel,
    SunatLotesModel,
    SunatCifradoLogic,
    SunatArchivosLogic,
    SunatConfiguracionLogic,
    SunatEmisionLogic,
    SunatLotesLogic,
    SunatProgramadorLogic,
  ],
  exports: [SunatEmisionLogic, SunatLotesLogic, SunatComprobantesModel],
})
export class SunatModule {}
