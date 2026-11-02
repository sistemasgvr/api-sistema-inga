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
import { UsuarioAuditoria } from '../../../common/decorators/usuario-auditoria.decorator';
import { EmpresaSesion } from '../../../common/decorators/sesion-empresa.decorator';

@ApiTags('Cuentas por Pagar - Proveedores')
@Controller('cuentas-por-pagar')
export class CuentasPorPagarController {
  constructor(private readonly logic: CuentasPorPagarLogic) {}

  @Get('saldos')
  @Permisos(PermisoBanderas.CXP_LISTAR)
  @ApiOperation({
    summary: 'Saldo deudor por proveedor, ordenado de mayor a menor deuda',
  })
  listarSaldos(
    @Query() filtros: FiltroSaldosDto,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.logic.listarSaldos(filtros, idEmpresa);
  }

  @Get('movimientos')
  @Permisos(PermisoBanderas.CXP_LISTAR)
  @ApiOperation({ summary: 'Historial de cargos y abonos con filtros' })
  listarMovimientos(
    @Query() filtros: FiltroMovimientosCxpDto,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.logic.listarMovimientos(filtros, idEmpresa);
  }

  @Get('reporte')
  @Permisos(PermisoBanderas.CXP_LISTAR)
  @ApiOperation({
    summary:
      'Reporte del período: cargos, abonos, desglose por proveedor y por semana',
  })
  reportePeriodo(
    @Query() filtros: FiltroReporteCxpDto,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.logic.reportePeriodo(filtros, idEmpresa);
  }

  @Get('movimientos/:id')
  @Permisos(PermisoBanderas.CXP_LISTAR)
  @ApiOperation({ summary: 'Obtener movimiento por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerMovimiento(
    @Param('id', ParseIntPipe) id: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.logic.obtenerMovimiento(id, idEmpresa);
  }

  @Get('proveedores/:idPersona')
  @Permisos(PermisoBanderas.CXP_LISTAR)
  @ApiOperation({
    summary:
      'Estado de cuenta del proveedor: saldo, totales y últimos movimientos',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerEstadoCuenta(
    @Param('idPersona', ParseIntPipe) idPersona: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.logic.obtenerEstadoCuenta(idPersona, undefined, idEmpresa);
  }

  @Post('cargos')
  @Permisos(PermisoBanderas.CXP_REGISTRAR_CARGO)
  @ApiOperation({
    summary:
      'Registrar compra a crédito (aumenta la deuda). M14 la llamará automáticamente.',
  })
  registrarCargo(
    @Body() dto: CreateCargoDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.logic.registrarCargo({ ...dto, idUsuarioAuditoria }, idEmpresa);
  }

  @Post('abonos')
  @Permisos(PermisoBanderas.CXP_REGISTRAR_ABONO)
  @ApiOperation({
    summary:
      'Registrar el abono semanal (reduce la deuda). No puede superar el saldo pendiente.',
  })
  registrarAbono(
    @Body() dto: CreateAbonoDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.logic.registrarAbono({ ...dto, idUsuarioAuditoria }, idEmpresa);
  }

  @Post('ajustes')
  @Permisos(PermisoBanderas.CXP_AJUSTAR)
  @ApiOperation({
    summary:
      'Ajuste manual del saldo. Monto con signo: positivo aumenta, negativo reduce.',
  })
  registrarAjuste(
    @Body() dto: CreateAjusteDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.logic.registrarAjuste(
      { ...dto, idUsuarioAuditoria },
      idEmpresa,
    );
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
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.logic.anularMovimiento(
      id,
      dto.motivo,
      idUsuarioAuditoria,
      idEmpresa,
    );
  }
}
