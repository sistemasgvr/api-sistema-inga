import { Module } from '@nestjs/common';
import { ApisPeruService } from './apisperu.service';

@Module({
  providers: [ApisPeruService],
  exports: [ApisPeruService],
})
export class ApisPeruModule {}
