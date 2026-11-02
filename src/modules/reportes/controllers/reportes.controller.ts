import { Controller, Get, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { FiltroReporteDto } from '../dto/reportes.dto';
import { ReportesLogic } from '../logic/reportes.logic';
import { EmpresaSesion } from '../../../common/decorators/sesion-empresa.decorator';

@ApiTags('Reportes')
@Controller('reportes')
export class ReportesController {
  constructor(private readonly logic: ReportesLogic) {}

  @Get('dashboard')
  @Permisos(PermisoBanderas.DASHBOARD_VER)
  @ApiOperation({
    summary:
      'Indicadores del dashboard: ventas por día, hora, canal, medio y mozo; platos vendidos con su costo; gastos y planilla',
  })
  dashboard(
    @Query() filtros: FiltroReporteDto,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.logic.dashboard(filtros, idEmpresa);
  }

  @Get('ventas')
  @Permisos(PermisoBanderas.REPORTES_VENTAS)
  @ApiOperation({
    summary:
      'Platos vendidos, ventas por medio, canal y mozo, y listado de ventas',
  })
  ventas(
    @Query() filtros: FiltroReporteDto,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.logic.ventas(filtros, idEmpresa);
  }

  @Get('gastos')
  @Permisos(PermisoBanderas.REPORTES_GASTOS)
  @ApiOperation({
    summary:
      'Compras del día por fecha e ítem y gastos administrativos del período',
  })
  gastos(
    @Query() filtros: FiltroReporteDto,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.logic.gastos(filtros, idEmpresa);
  }

  @Get('caja')
  @Permisos(PermisoBanderas.REPORTES_CAJA)
  @ApiOperation({
    summary:
      'Turnos de caja con sus totales y diferencias, y movimientos manuales',
  })
  caja(
    @Query() filtros: FiltroReporteDto,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.logic.caja(filtros, idEmpresa);
  }

  @Get('cuentas')
  @Permisos(PermisoBanderas.REPORTES_CUENTAS)
  @ApiOperation({
    summary:
      'Saldos de cuentas por cobrar y por pagar con lo movido en el período',
  })
  cuentas(
    @Query() filtros: FiltroReporteDto,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.logic.cuentas(filtros, idEmpresa);
  }

  @Get('planilla')
  @Permisos(PermisoBanderas.REPORTES_PLANILLA)
  @ApiOperation({ summary: 'Pagos de planilla del período' })
  planilla(
    @Query() filtros: FiltroReporteDto,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.logic.planilla(filtros, idEmpresa);
  }

  @Get('inventario')
  @Permisos(PermisoBanderas.REPORTES_INVENTARIO)
  @ApiOperation({
    summary: 'Stock valorizado actual y movimientos de almacén del período',
  })
  inventario(
    @Query() filtros: FiltroReporteDto,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.logic.inventario(filtros, idEmpresa);
  }

  @Get('general')
  @Permisos(PermisoBanderas.REPORTES_GENERAL)
  @ApiOperation({
    summary:
      'Reporte consolidado: estado de resultados, cobros, caja, cuentas e inventario',
  })
  general(
    @Query() filtros: FiltroReporteDto,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.logic.general(filtros, idEmpresa);
  }
}
