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
  AnularMovimientoCxcDto,
  CreateAbonoCxcDto,
  CreateAjusteCxcDto,
  CreateConsumoDto,
  FiltroEstadoCuentaDto,
  FiltroMovimientosCxcDto,
  FiltroReporteCxcDto,
  FiltroSaldosCxcDto,
} from '../dto/cuentas-por-cobrar.dto';
import { CuentasPorCobrarLogic } from '../logic/cuentas-por-cobrar.logic';

@ApiTags('Cuentas por Cobrar - Consorcio')
@Controller('cuentas-por-cobrar')
export class CuentasPorCobrarController {
  constructor(private readonly logic: CuentasPorCobrarLogic) {}

  @Get('saldos')
  @Permisos(PermisoBanderas.CXC_LISTAR)
  @ApiOperation({
    summary: 'Saldo de cada cliente del consorcio, ordenado de mayor a menor deuda',
  })
  listarSaldos(@Query() filtros: FiltroSaldosCxcDto) {
    return this.logic.listarSaldos(filtros);
  }

  @Get('movimientos')
  @Permisos(PermisoBanderas.CXC_LISTAR)
  @ApiOperation({ summary: 'Historial de consumos y abonos con filtros' })
  listarMovimientos(@Query() filtros: FiltroMovimientosCxcDto) {
    return this.logic.listarMovimientos(filtros);
  }

  // Las rutas literales van ANTES de las que tienen :id. Nest resuelve en orden
  // de declaración, así que 'reporte' tiene que estar arriba o nunca se alcanza.
  @Get('reporte')
  @Permisos(PermisoBanderas.CXC_LISTAR)
  @ApiOperation({
    summary:
      'Reporte de la quincena agrupado por empresa, con el detalle de cada trabajador. ' +
      'Sin período, usa la quincena en curso. Es lo que se le envía a cada empresa.',
  })
  reportePeriodo(@Query() filtros: FiltroReporteCxcDto) {
    return this.logic.reportePeriodo(filtros);
  }

  @Get('movimientos/:id')
  @Permisos(PermisoBanderas.CXC_LISTAR)
  @ApiOperation({ summary: 'Obtener movimiento por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerMovimiento(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtenerMovimiento(id);
  }

  @Get('clientes/:idPersona')
  @Permisos(PermisoBanderas.CXC_LISTAR)
  @ApiOperation({
    summary:
      'Estado de cuenta del cliente: saldo, crédito disponible y movimientos del ' +
      'más antiguo al más reciente. Sin período, trae el historial completo.',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerEstadoCuenta(
    @Param('idPersona', ParseIntPipe) idPersona: number,
    @Query() filtros: FiltroEstadoCuentaDto,
  ) {
    return this.logic.obtenerEstadoCuenta(idPersona, filtros);
  }

  @Post('consumos')
  @Permisos(PermisoBanderas.CXC_REGISTRAR_CONSUMO)
  @ApiOperation({
    summary:
      'Registrar consumo a crédito (aumenta la deuda). M12 la llamará automáticamente ' +
      'al cobrar un pedido con medio de pago crédito. Devuelve supera_limite cuando ' +
      'el saldo pasa el tope del convenio: advierte, no bloquea.',
  })
  registrarConsumo(@Body() dto: CreateConsumoDto) {
    return this.logic.registrarConsumo(dto);
  }

  @Post('abonos')
  @Permisos(PermisoBanderas.CXC_REGISTRAR_ABONO)
  @ApiOperation({
    summary:
      'Registrar el pago de la empresa o el descuento por planilla (reduce la deuda). ' +
      'No puede superar el saldo pendiente.',
  })
  registrarAbono(@Body() dto: CreateAbonoCxcDto) {
    return this.logic.registrarAbono(dto);
  }

  @Post('ajustes')
  @Permisos(PermisoBanderas.CXC_AJUSTAR)
  @ApiOperation({
    summary:
      'Ajuste manual del saldo. Monto con signo: positivo aumenta, negativo reduce. ' +
      'Exige motivo.',
  })
  registrarAjuste(@Body() dto: CreateAjusteCxcDto) {
    return this.logic.registrarAjuste(dto);
  }

  @Delete('movimientos/:id')
  @Permisos(PermisoBanderas.CXC_AJUSTAR)
  @ApiOperation({
    summary:
      'Anular movimiento (borrado lógico). No aplica a consumos que vienen de un ' +
      'pedido ni a quincenas ya cerradas: para eso está el ajuste.',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  anularMovimiento(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AnularMovimientoCxcDto,
  ) {
    return this.logic.anularMovimiento(id, dto.motivo, dto.idUsuarioAuditoria);
  }
}
