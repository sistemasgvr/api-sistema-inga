import { Module } from '@nestjs/common';
import { EmpresaController } from './controllers/empresa.controller';
import { EmpresaLogic } from './logic/empresa.logic';
import { EmpresaModel } from './models/empresa.model';

@Module({
  controllers: [EmpresaController],
  providers: [EmpresaLogic, EmpresaModel],
  exports: [EmpresaLogic],
})
export class EmpresaModule {}
