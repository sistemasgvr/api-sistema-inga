import { Module } from '@nestjs/common';
import { ApisPeruService } from './apisperu.service';
import { ApisPeruConsultasService } from './apisperu-consultas.service';

@Module({
  providers: [ApisPeruService, ApisPeruConsultasService],
  exports: [ApisPeruService, ApisPeruConsultasService],
})
export class ApisPeruModule {}
