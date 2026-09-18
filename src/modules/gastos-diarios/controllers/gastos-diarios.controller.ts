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
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import {
  AbrirDiaDto,
  AnularLineaDto,
  CreateInsumoDto,
  CreateLineaDto,
  FiltroDiasDto,
  FiltroInsumosDto,
  FiltroReporteDiaDto,
  UpdateInsumoDto,
} from '../dto/gastos-diarios.dto';
import { GastosDiariosLogic } from '../logic/gastos-diarios.logic';

@ApiTags('Gastos Diarios Operativos')
@Controller('gastos-diarios')
export class GastosDiariosController {
  constructor(private readonly logic: GastosDiariosLogic) {}

  /* -------------------------------- Insumos -------------------------------- */

  @Get('insumos')
  @Permisos(PermisoBanderas.GDO_LISTAR)
  @ApiOperation({
    summary: 'Lista maestra de insumos, agrupada por categoría y sin paginar',
  })
  listarInsumos(@Query() filtros: FiltroInsumosDto) {
    return this.logic.listarInsumos(filtros);
  }

  @Get('insumos/:id')
  @Permisos(PermisoBanderas.GDO_LISTAR)
  @ApiOperation({ summary: 'Obtener insumo por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerInsumo(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtenerInsumo(id);
  }

  @Post('insumos')
  @Permisos(PermisoBanderas.GDO_REGISTRAR)
  @ApiOperation({
    summary:
      'Crear insumo. Lo usa también el registro rápido para crear "al vuelo" lo que no está en la lista.',
  })
  crearInsumo(@Body() dto: CreateInsumoDto) {
    return this.logic.crearInsumo(dto);
  }

  @Patch('insumos/:id')
  @Permisos(PermisoBanderas.GDO_INSUMOS_GESTIONAR)
  @ApiOperation({ summary: 'Actualizar insumo de la lista maestra' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizarInsumo(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateInsumoDto,
  ) {
    return this.logic.actualizarInsumo(id, dto);
  }

  @Delete('insumos/:id')
  @Permisos(PermisoBanderas.GDO_INSUMOS_GESTIONAR)
  @ApiOperation({ summary: 'Dar de baja o reactivar un insumo (alterna el estado)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  toggleInsumo(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.logic.toggleInsumo(id, dto.idUsuarioAuditoria);
  }

  /* ------------------------------ Gasto del día ---------------------------- */

  @Get('dias')
  @Permisos(PermisoBanderas.GDO_LISTAR)
  @ApiOperation({ summary: 'Historial de días con gasto, con totales por forma de pago' })
  listarDias(@Query() filtros: FiltroDiasDto) {
    return this.logic.listarDias(filtros);
  }

  // Va antes de 'dias/:id' porque Nest resuelve las rutas en orden de
  // declaración: si ':id' fuera primero, capturaría la palabra "reporte".
  @Get('dias/reporte')
  @Permisos(PermisoBanderas.GDO_LISTAR)
  @ApiOperation({
    summary:
      'Cuadre del día: totales por forma de pago, desglose por categoría y por proveedor a crédito',
  })
  reporteDia(@Query() filtros: FiltroReporteDiaDto) {
    return this.logic.reporteDia(filtros);
  }

  @Get('dias/:id')
  @Permisos(PermisoBanderas.GDO_LISTAR)
  @ApiOperation({ summary: 'Obtener el gasto de un día con todas sus líneas' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerDia(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtenerDia(id);
  }

  @Post('dias/abrir')
  @Permisos(PermisoBanderas.GDO_REGISTRAR)
  @ApiOperation({
    summary: 'Abrir el gasto del día. Idempotente: si ya existe, lo devuelve.',
  })
  abrirDia(@Body() dto: AbrirDiaDto) {
    return this.logic.abrirDia(dto);
  }

  @Post('dias/:id/lineas')
  @Permisos(PermisoBanderas.GDO_REGISTRAR)
  @ApiOperation({
    summary:
      'Agregar una compra al día. Si es a crédito, genera automáticamente la deuda en CxP.',
  })
  agregarLinea(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: CreateLineaDto,
  ) {
    return this.logic.agregarLinea(id, dto);
  }

  @Delete('lineas/:id')
  @Permisos(PermisoBanderas.GDO_ANULAR)
  @ApiOperation({
    summary: 'Anular una compra. Si era a crédito, revierte la deuda generada en CxP.',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  anularLinea(@Param('id', ParseIntPipe) id: number, @Body() dto: AnularLineaDto) {
    return this.logic.anularLinea(id, dto.motivo, dto.idUsuarioAuditoria);
  }
}
