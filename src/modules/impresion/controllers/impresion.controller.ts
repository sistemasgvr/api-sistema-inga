import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Query,
} from '@nestjs/common';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { ImpresionLogic } from '../logic/impresion.logic';
import { QzSigningLogic } from '../logic/qz-signing.logic';
import {
  ConfirmarImpresionDto,
  ResolverImpresionDto,
  FirmaQzDto,
} from '../dto/impresion.dto';

@Controller('impresion')
@Permisos(PermisoBanderas.ESTACIONES_LISTAR, PermisoBanderas.PEDIDOS_COMANDAR)
export class ImpresionController {
  constructor(
    private readonly service: ImpresionLogic,
    private readonly qz: QzSigningLogic,
  ) {}
  @Get('qz/certificado')
  certificado() {
    return this.qz.certificado();
  }
  @Post('qz/firmar')
  firmar(@Body() dto: FirmaQzDto) {
    return this.qz.firmar(dto.mensaje);
  }
  @Get('pendientes')
  pendientes(@Query('estacion', ParseIntPipe) estacion: number) {
    return this.service.pendientes([estacion]);
  }
  @Post(':id/confirmar')
  confirmar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: ConfirmarImpresionDto,
  ) {
    return this.service.confirmar(
      String(id),
      dto.propietario,
      dto.enviado,
      dto.error,
    );
  }
  @Post(':id/resolver')
  resolver(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: ResolverImpresionDto,
  ) {
    return this.service.resolver(String(id), dto.enviado);
  }
}
