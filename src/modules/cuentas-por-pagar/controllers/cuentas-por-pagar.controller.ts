import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Query,
} from '@nestjs/common';
import { ApiNotFoundResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import {
  AnularMovimientoCxpDto,
  CreateAbonoDto,
  CreateAjusteDto,
  CreateCargoDto,
  FiltroMovimientosCxpDto,
  FiltroReporteCxpDto,
  FiltroSaldosDto,
} from '../dto/cuentas-por-pagar.dto';
import { CuentasPorPagarLogic } from '../logic/cuentas-por-pagar.logic';

@ApiTags('Cuentas por Pagar - Proveedores')
@Controller('cuentas-por-pagar')
export class CuentasPorPagarController {
  constructor(private readonly logic: CuentasPorPagarLogic) {}

  @Get('saldos')
  @Permisos(PermisoBanderas.CXP_LISTAR)
  @ApiOperation({
    summary: 'Saldo deudor por proveedor, ordenado de mayor a menor deuda',
  })
  listarSaldos(@Query() filtros: FiltroSaldosDto) {
    return this.logic.listarSaldos(filtros);
  }

  @Get('movimientos')
  @Permisos(PermisoBanderas.CXP_LISTAR)
  @ApiOperation({ summary: 'Historial de cargos y abonos con filtros' })
  listarMovimientos(@Query() filtros: FiltroMovimientosCxpDto) {
    return this.logic.listarMovimientos(filtros);
  }

  // Va antes de 'movimientos/:id' porque Nest resuelve las rutas en orden de
  // declaración: si ':id' fuera primero, no habría problema acá por ser rutas
  // distintas, pero mantengo el criterio para que no sorprenda al agregar más.
  @Get('reporte')
  @Permisos(PermisoBanderas.CXP_LISTAR)
  @ApiOperation({
    summary: 'Reporte del período: cargos, abonos, desglose por proveedor y por semana',
  })
  reportePeriodo(@Query() filtros: FiltroReporteCxpDto) {
    return this.logic.reportePeriodo(filtros);
  }

  @Get('movimientos/:id')
  @Permisos(PermisoBanderas.CXP_LISTAR)
  @ApiOperation({ summary: 'Obtener movimiento por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerMovimiento(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtenerMovimiento(id);
  }

  @Get('proveedores/:idPersona')
  @Permisos(PermisoBanderas.CXP_LISTAR)
  @ApiOperation({
    summary: 'Estado de cuenta del proveedor: saldo, totales y últimos movimientos',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerEstadoCuenta(@Param('idPersona', ParseIntPipe) idPersona: number) {
    return this.logic.obtenerEstadoCuenta(idPersona);
  }

  @Post('cargos')
  @Permisos(PermisoBanderas.CXP_REGISTRAR_CARGO)
  @ApiOperation({
    summary:
      'Registrar compra a crédito (aumenta la deuda). M14 la llamará automáticamente.',
  })
  registrarCargo(@Body() dto: CreateCargoDto) {
    return this.logic.registrarCargo(dto);
  }

  @Post('abonos')
  @Permisos(PermisoBanderas.CXP_REGISTRAR_ABONO)
  @ApiOperation({
    summary:
      'Registrar el abono semanal (reduce la deuda). No puede superar el saldo pendiente.',
  })
  registrarAbono(@Body() dto: CreateAbonoDto) {
    return this.logic.registrarAbono(dto);
  }

  @Post('ajustes')
  @Permisos(PermisoBanderas.CXP_AJUSTAR)
  @ApiOperation({
    summary:
      'Ajuste manual del saldo. Monto con signo: positivo aumenta, negativo reduce.',
  })
  registrarAjuste(@Body() dto: CreateAjusteDto) {
    return this.logic.registrarAjuste(dto);
  }

  @Delete('movimientos/:id')
  @Permisos(PermisoBanderas.CXP_AJUSTAR)
  @ApiOperation({
    summary:
      'Anular movimiento. Solo el último del proveedor, para no romper el histórico de saldos.',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  anularMovimiento(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AnularMovimientoCxpDto,
  ) {
    return this.logic.anularMovimiento(id, dto.motivo, dto.idUsuarioAuditoria);
  }
}
