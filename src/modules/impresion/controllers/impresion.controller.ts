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
import { archivoPdf, TicketPdfLogic } from '../logic/ticket-pdf.logic';
import { EmpresaLogic } from '../../empresa/logic/empresa.logic';
import { QzConfiguracionDto } from '../dto/qz-configuracion.dto';
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
    private readonly empresa: EmpresaLogic,
    private readonly tickets: TicketPdfLogic,
  ) {}
  // Encabezado de los tickets (logo, RUC, razón social y dirección).
  @Get('empresa')
  datosEmpresa() {
    return this.empresa.datosTicket();
  }
  @Get('qz/configuracion')
  @Permisos(PermisoBanderas.ESTACIONES_EDITAR)
  configuracionQz() {
    return this.qz.configuracion();
  }

  @Post('qz/configuracion')
  @Permisos(PermisoBanderas.ESTACIONES_EDITAR)
  guardarConfiguracionQz(@Body() dto: QzConfiguracionDto) {
    return this.qz.guardarConfiguracion(dto.certificado, dto.clavePrivada);
  }
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
  // PDF archivado en Storage del ticket (comanda, precuenta o comprobante).
  @Get(':id/pdf')
  async pdf(@Param('id', ParseIntPipe) id: number) {
    return archivoPdf(await this.tickets.trabajo(id));
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
      dto.reintentable,
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
