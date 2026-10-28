import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Query,
} from '@nestjs/common';
import { ApiOperation, ApiProduces, ApiTags } from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { UsuarioAuditoria } from '../../../common/decorators/usuario-auditoria.decorator';
import {
  BajaSunatDto,
  BandejaSunatDto,
  EnviarDiaDto,
  FechaSunatDto,
  FiltroLotesDto,
} from '../dto/sunat.dto';
import { archivoSunat } from '../logic/sunat-archivos.logic';
import { SunatEmisionLogic } from '../logic/sunat-emision.logic';
import { SunatLotesLogic } from '../logic/sunat-lotes.logic';

@ApiTags('SUNAT')
@Controller('sunat')
export class SunatController {
  constructor(
    private readonly emision: SunatEmisionLogic,
    private readonly lotes: SunatLotesLogic,
  ) {}

  @Get('pendientes')
  @Permisos(PermisoBanderas.SUNAT_LISTAR)
  @ApiOperation({
    summary:
      'Boletas y facturas pendientes, en proceso o rechazadas (o del estado indicado), ordenadas por fecha límite',
  })
  pendientes(@Query() filtro: BandejaSunatDto) {
    return this.emision.bandeja(filtro);
  }

  @Get('resumen-dia')
  @Permisos(PermisoBanderas.SUNAT_LISTAR)
  @ApiOperation({
    summary: 'Comprobantes del día por tipo y estado SUNAT (por defecto, hoy)',
  })
  resumenDia(@Query() dto: FechaSunatDto) {
    return this.lotes.resumenDia(dto.fecha);
  }

  @Post('resumen-dia/enviar')
  @Permisos(PermisoBanderas.SUNAT_CREAR)
  @ApiOperation({
    summary:
      'Envío masivo del día: facturas una por una y boletas en resumen diario',
  })
  enviarDia(@Body() dto: EnviarDiaDto, @UsuarioAuditoria() usuario: number) {
    return this.lotes.enviarDia(dto.fecha, usuario);
  }

  @Get('comprobantes/:id')
  @Permisos(PermisoBanderas.SUNAT_LISTAR)
  @ApiOperation({ summary: 'Estado SUNAT del comprobante' })
  estado(@Param('id', ParseIntPipe) id: number) {
    return this.emision.estado(id);
  }

  @Get('comprobantes/:id/historial')
  @Permisos(PermisoBanderas.SUNAT_LISTAR)
  @ApiOperation({ summary: 'Envíos y respuestas de SUNAT del comprobante' })
  historial(@Param('id', ParseIntPipe) id: number) {
    return this.emision.historial(id);
  }

  @Post('comprobantes/:id/enviar')
  @Permisos(PermisoBanderas.SUNAT_CREAR)
  @ApiOperation({
    summary: 'Enviar a SUNAT una boleta o factura pendiente',
  })
  enviar(
    @Param('id', ParseIntPipe) id: number,
    @UsuarioAuditoria() usuario: number,
  ) {
    return this.emision.enviar(id, usuario);
  }

  @Post('comprobantes/:id/consultar')
  @Permisos(PermisoBanderas.SUNAT_CREAR)
  @ApiOperation({ summary: 'Consultar el CDR de una factura en SUNAT' })
  consultar(
    @Param('id', ParseIntPipe) id: number,
    @UsuarioAuditoria() usuario: number,
  ) {
    return this.emision.consultar(id, usuario);
  }

  @Post('comprobantes/:id/baja')
  @Permisos(PermisoBanderas.SUNAT_ELIMINAR)
  @ApiOperation({
    summary:
      'Dar de baja en SUNAT un comprobante aceptado (factura: comunicación de baja; boleta: resumen con estado 3). Hasta 7 días',
  })
  baja(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: BajaSunatDto,
    @UsuarioAuditoria() usuario: number,
  ) {
    return this.lotes.darDeBaja([id], dto.motivo, usuario);
  }

  @Get('comprobantes/:id/xml')
  @Permisos(PermisoBanderas.SUNAT_LISTAR)
  @ApiProduces('application/xml')
  @ApiOperation({ summary: 'Descargar el XML firmado del comprobante' })
  async xml(@Param('id', ParseIntPipe) id: number) {
    return archivoSunat(await this.emision.xml(id));
  }

  @Get('comprobantes/:id/cdr')
  @Permisos(PermisoBanderas.SUNAT_LISTAR)
  @ApiProduces('application/zip')
  @ApiOperation({
    summary: 'Descargar el CDR (constancia de recepción de SUNAT)',
  })
  async cdr(@Param('id', ParseIntPipe) id: number) {
    return archivoSunat(await this.emision.cdr(id));
  }

  @Get('comprobantes/:id/pdf-a4')
  @Permisos(PermisoBanderas.SUNAT_LISTAR)
  @ApiProduces('application/pdf')
  @ApiOperation({ summary: 'PDF A4 del comprobante (generado por APIsPERU)' })
  async pdfA4(@Param('id', ParseIntPipe) id: number) {
    return archivoSunat(await this.emision.pdfA4(id));
  }

  @Get('lotes')
  @Permisos(PermisoBanderas.SUNAT_LISTAR)
  @ApiOperation({
    summary: 'Resúmenes diarios (RC) y comunicaciones de baja (RA) enviados',
  })
  listarLotes(@Query() filtro: FiltroLotesDto) {
    return this.lotes.listar(filtro);
  }

  @Get('lotes/:id')
  @Permisos(PermisoBanderas.SUNAT_LISTAR)
  @ApiOperation({
    summary: 'Detalle de un resumen o baja con sus comprobantes',
  })
  lote(@Param('id', ParseIntPipe) id: number) {
    return this.lotes.obtener(id);
  }

  @Post('lotes/:id/consultar')
  @Permisos(PermisoBanderas.SUNAT_CREAR)
  @ApiOperation({ summary: 'Consultar en SUNAT el ticket del resumen o baja' })
  consultarLote(@Param('id', ParseIntPipe) id: number) {
    return this.lotes.consultar(id);
  }

  @Get('lotes/:id/xml')
  @Permisos(PermisoBanderas.SUNAT_LISTAR)
  @ApiProduces('application/xml')
  @ApiOperation({ summary: 'Descargar el XML del resumen o baja' })
  async loteXml(@Param('id', ParseIntPipe) id: number) {
    return archivoSunat(await this.lotes.archivo(id, 'xml'));
  }

  @Get('lotes/:id/cdr')
  @Permisos(PermisoBanderas.SUNAT_LISTAR)
  @ApiProduces('application/zip')
  @ApiOperation({ summary: 'Descargar el CDR del resumen o baja' })
  async loteCdr(@Param('id', ParseIntPipe) id: number) {
    return archivoSunat(await this.lotes.archivo(id, 'cdr'));
  }
}
