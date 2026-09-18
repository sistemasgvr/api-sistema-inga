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
  AnularGastoDto,
  CreateCategoriaGastoDto,
  CreateGastoDto,
  FiltroCategoriasGastoDto,
  FiltroGastosDto,
  FiltroReporteMensualDto,
  UpdateCategoriaGastoDto,
  UpdateGastoDto,
} from '../dto/gastos-administrativos.dto';
import { GastosAdministrativosLogic } from '../logic/gastos-administrativos.logic';

@ApiTags('Gastos administrativos')
@Controller('gastos-administrativos')
export class GastosAdministrativosController {
  constructor(private readonly logic: GastosAdministrativosLogic) {}

  /* ------------------------------ Categorías ------------------------------ */

  @Get('categorias')
  @Permisos(PermisoBanderas.GASTOS_CATEGORIAS_LISTAR)
  @ApiOperation({
    summary: 'Listar categorías en árbol, con sus subcategorías anidadas',
  })
  listarCategorias(@Query() filtros: FiltroCategoriasGastoDto) {
    return this.logic.listarCategorias(filtros);
  }

  @Get('categorias/:id')
  @Permisos(PermisoBanderas.GASTOS_CATEGORIAS_LISTAR)
  @ApiOperation({ summary: 'Obtener categoría por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerCategoria(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtenerCategoria(id);
  }

  @Post('categorias')
  @Permisos(PermisoBanderas.GASTOS_CATEGORIAS_GESTIONAR)
  @ApiOperation({
    summary: 'Crear categoría o subcategoría (solo un nivel de anidación)',
  })
  crearCategoria(@Body() dto: CreateCategoriaGastoDto) {
    return this.logic.crearCategoria(dto);
  }

  @Patch('categorias/:id')
  @Permisos(PermisoBanderas.GASTOS_CATEGORIAS_GESTIONAR)
  @ApiOperation({ summary: 'Actualizar categoría' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizarCategoria(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateCategoriaGastoDto,
  ) {
    return this.logic.actualizarCategoria(id, dto);
  }

  @Patch('categorias/:id/activar')
  @Permisos(PermisoBanderas.GASTOS_CATEGORIAS_GESTIONAR)
  @ApiOperation({ summary: 'Reactivar categoría' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  activarCategoria(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.logic.activarCategoria(id, dto.idUsuarioAuditoria);
  }

  @Delete('categorias/:id')
  @Permisos(PermisoBanderas.GASTOS_CATEGORIAS_GESTIONAR)
  @ApiOperation({
    summary: 'Dar de baja categoría (falla si tiene gastos o subcategorías activas)',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminarCategoria(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.logic.eliminarCategoria(id, dto.idUsuarioAuditoria);
  }

  /* -------------------------------- Gastos -------------------------------- */

  @Get()
  @Permisos(PermisoBanderas.GASTOS_LISTAR)
  @ApiOperation({
    summary: 'Listar gastos, con desglose por tipo y medio de pago',
  })
  listarGastos(@Query() filtros: FiltroGastosDto) {
    return this.logic.listarGastos(filtros);
  }

  // Va antes de @Get(':id') porque Nest resuelve las rutas en orden de
  // declaración: si ':id' fuera primero, capturaría la palabra "reporte" y el
  // ParseIntPipe devolvería un 400.
  @Get('reporte')
  @Permisos(PermisoBanderas.GASTOS_LISTAR)
  @ApiOperation({
    summary:
      'Reporte mensual: totales por tipo y medio, desglose por categoría y comparación con el mes anterior',
  })
  reporteMensual(@Query() filtros: FiltroReporteMensualDto) {
    return this.logic.reporteMensual(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.GASTOS_LISTAR)
  @ApiOperation({ summary: 'Obtener gasto por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerGasto(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtenerGasto(id);
  }

  @Post()
  @Permisos(PermisoBanderas.GASTOS_REGISTRAR)
  @ApiOperation({
    summary: 'Registrar gasto. En efectivo exige un turno de caja abierto',
  })
  registrarGasto(@Body() dto: CreateGastoDto) {
    return this.logic.registrarGasto(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.GASTOS_REGISTRAR)
  @ApiOperation({
    summary: 'Actualizar gasto (falla si fue en efectivo y su turno ya se cerró)',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizarGasto(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateGastoDto,
  ) {
    return this.logic.actualizarGasto(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.GASTOS_ANULAR)
  @ApiOperation({
    summary: 'Anular gasto (falla si fue en efectivo y su turno ya se cerró)',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  anularGasto(@Param('id', ParseIntPipe) id: number, @Body() dto: AnularGastoDto) {
    return this.logic.anularGasto(id, dto.motivo, dto.idUsuarioAuditoria);
  }
}
