import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiNotFoundResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import {
  AnularPagoDto,
  CreatePagoDto,
  CreateTrabajadorDto,
  FiltroPagosDto,
  FiltroReportePeriodoDto,
  FiltroTrabajadoresDto,
  UpdateTrabajadorDto,
} from '../dto/planilla.dto';
import { PlanillaLogic } from '../logic/planilla.logic';
import { UsuarioAuditoria } from '../../../common/decorators/usuario-auditoria.decorator';

@ApiTags('Planilla - Trabajadores y pagos')
@Controller('planilla')
export class PlanillaController {
  constructor(private readonly planillaLogic: PlanillaLogic) {}

  @Get('trabajadores')
  @Permisos(PermisoBanderas.TRABAJADORES_LISTAR)
  @ApiOperation({
    summary:
      'Listar trabajadores, con lo pagado en el período y su último pago',
  })
  listarTrabajadores(@Query() filtros: FiltroTrabajadoresDto) {
    return this.planillaLogic.listarTrabajadores(filtros);
  }

  @Get('trabajadores/:id')
  @Permisos(PermisoBanderas.TRABAJADORES_VER)
  @ApiOperation({ summary: 'Obtener trabajador por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerTrabajador(@Param('id', ParseIntPipe) id: number) {
    return this.planillaLogic.obtenerTrabajador(id);
  }

  @Post('trabajadores')
  @Permisos(PermisoBanderas.TRABAJADORES_CREAR)
  @ApiOperation({ summary: 'Registrar trabajador' })
  crearTrabajador(
    @Body() dto: CreateTrabajadorDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
  ) {
    return this.planillaLogic.crearTrabajador({ ...dto, idUsuarioAuditoria });
  }

  @Patch('trabajadores/:id')
  @Permisos(PermisoBanderas.TRABAJADORES_EDITAR)
  @ApiOperation({ summary: 'Actualizar trabajador' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizarTrabajador(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateTrabajadorDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
  ) {
    return this.planillaLogic.actualizarTrabajador(id, {
      ...dto,
      idUsuarioAuditoria,
    });
  }

  @Patch('trabajadores/:id/activar')
  @Permisos(PermisoBanderas.TRABAJADORES_ACTIVAR)
  @ApiOperation({ summary: 'Reactivar trabajador' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  activarTrabajador(
    @Param('id', ParseIntPipe) id: number,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
  ) {
    return this.planillaLogic.activarTrabajador(id, idUsuarioAuditoria);
  }

  @Delete('trabajadores/:id')
  @Permisos(PermisoBanderas.TRABAJADORES_ELIMINAR)
  @ApiOperation({ summary: 'Dar de baja trabajador (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminarTrabajador(
    @Param('id', ParseIntPipe) id: number,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
  ) {
    return this.planillaLogic.eliminarTrabajador(id, idUsuarioAuditoria);
  }

  @Get('pagos')
  @Permisos(PermisoBanderas.PLANILLA_PAGOS_LISTAR)
  @ApiOperation({
    summary: 'Listar pagos de planilla, con desglose por medio de pago',
  })
  listarPagos(@Query() filtros: FiltroPagosDto) {
    return this.planillaLogic.listarPagos(filtros);
  }

  @Get('pagos/reporte')
  @Permisos(PermisoBanderas.PLANILLA_PAGOS_LISTAR)
  @ApiOperation({
    summary: 'Reporte del período: pagados, pendientes y totales por medio',
  })
  reportePeriodo(@Query() filtros: FiltroReportePeriodoDto) {
    return this.planillaLogic.reportePeriodo(filtros);
  }

  @Get('pagos/:id')
  @Permisos(PermisoBanderas.PLANILLA_PAGOS_LISTAR)
  @ApiOperation({ summary: 'Obtener pago por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPago(@Param('id', ParseIntPipe) id: number) {
    return this.planillaLogic.obtenerPago(id);
  }

  @Post('pagos')
  @Permisos(PermisoBanderas.PLANILLA_PAGOS_REGISTRAR)
  @ApiOperation({
    summary:
      'Registrar pago. La quincena se deduce de la fecha; en efectivo exige turno abierto',
  })
  registrarPago(
    @Body() dto: CreatePagoDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
  ) {
    return this.planillaLogic.registrarPago({ ...dto, idUsuarioAuditoria });
  }

  @Delete('pagos/:id')
  @Permisos(PermisoBanderas.PLANILLA_PAGOS_ANULAR)
  @ApiOperation({
    summary:
      'Anular pago (falla si fue en efectivo y su turno ya está cerrado)',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  anularPago(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AnularPagoDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
  ) {
    return this.planillaLogic.anularPago(id, dto.motivo, idUsuarioAuditoria);
  }
}
