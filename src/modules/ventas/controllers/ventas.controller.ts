import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiOperation, ApiProduces, ApiTags } from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { EmpresaSesion } from '../../../common/decorators/sesion-empresa.decorator';
import { UsuarioAuditoria } from '../../../common/decorators/usuario-auditoria.decorator';
import {
  CambiarMedioPagoDto,
  FiltroVentasDto,
  ReemitirComprobanteDto,
} from '../dto/ventas.dto';
import { archivoPdf } from '../../impresion/logic/ticket-pdf.logic';
import { VentasLogic } from '../logic/ventas.logic';

@ApiTags('Ventas')
@Controller('ventas')
export class VentasController {
  constructor(private readonly logic: VentasLogic) {}

  @Get()
  @Permisos(PermisoBanderas.VENTAS_LISTAR)
  @ApiOperation({
    summary:
      'Pedidos cobrados con su comprobante vigente, pagos y caja; incluye resumen por medio de pago',
  })
  listar(@Query() filtros: FiltroVentasDto) {
    return this.logic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.VENTAS_LISTAR)
  @ApiOperation({
    summary: 'Venta con pagos, historial de comprobantes y comandas',
  })
  obtener(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtener(id);
  }

  @Patch('pagos/:idPago/medio')
  @Permisos(PermisoBanderas.VENTAS_CAMBIAR_PAGO)
  @ApiOperation({
    summary:
      'Cambiar el medio de pago (efectivo, Yape, tarjeta). Si la caja del pago ya cerró, recalcula su cierre',
  })
  cambiarMedioPago(
    @Param('idPago', ParseIntPipe) idPago: number,
    @Body() dto: CambiarMedioPagoDto,
    @UsuarioAuditoria() usuario: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.logic.cambiarMedioPago(idPago, dto.medio_pago, usuario, idEmpresa);
  }

  @Post(':id/reemitir')
  @Permisos(PermisoBanderas.VENTAS_REEMITIR)
  @ApiOperation({
    summary:
      'Anular el comprobante vigente y emitir uno nuevo con otro número, enlazado al anterior',
  })
  reemitir(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: ReemitirComprobanteDto,
    @UsuarioAuditoria() usuario: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.logic.reemitirComprobante(id, dto, usuario, idEmpresa);
  }

  @Get('comandas/:idComanda/pdf')
  @Permisos(PermisoBanderas.VENTAS_LISTAR)
  @ApiProduces('application/pdf')
  @ApiOperation({
    summary:
      'PDF con forma de ticket de una comanda, precuenta o comprobante impreso. Se archiva en Storage la primera vez',
  })
  async comandaPdf(@Param('idComanda', ParseIntPipe) idComanda: number) {
    return archivoPdf(await this.logic.comandaPdf(idComanda));
  }

  @Get('comprobantes/:idComprobante/pdf')
  @Permisos(PermisoBanderas.VENTAS_LISTAR)
  @ApiProduces('application/pdf')
  @ApiOperation({
    summary:
      'PDF con forma de ticket del comprobante (boleta, factura o nota de venta), leído desde Storage; se genera y archiva si aún no existe',
  })
  async comprobantePdf(
    @Param('idComprobante', ParseIntPipe) idComprobante: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return archivoPdf(
      await this.logic.comprobantePdf(idComprobante, idEmpresa),
    );
  }

  @Post('comandas/:idComanda/reimprimir')
  @Permisos(PermisoBanderas.VENTAS_REIMPRIMIR)
  @ApiOperation({
    summary: 'Volver a enviar una comanda o precuenta a la cola de impresión',
  })
  reimprimirComanda(
    @Param('idComanda', ParseIntPipe) idComanda: number,
    @UsuarioAuditoria() usuario: number,
  ) {
    return this.logic.reimprimirComanda(idComanda, usuario);
  }

  @Post('comprobantes/:idComprobante/imprimir')
  @Permisos(PermisoBanderas.VENTAS_REIMPRIMIR)
  @ApiOperation({
    summary: 'Imprimir el comprobante vigente en la estación principal de caja',
  })
  imprimirComprobante(
    @Param('idComprobante', ParseIntPipe) idComprobante: number,
    @UsuarioAuditoria() usuario: number,
  ) {
    return this.logic.imprimirComprobante(idComprobante, usuario);
  }
}
