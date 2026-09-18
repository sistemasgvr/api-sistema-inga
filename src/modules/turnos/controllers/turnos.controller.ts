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
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import {
  AbrirTurnoDto,
  CerrarTurnoDto,
  CreateMovimientoDto,
  FiltroTurnosDto,
  GuardarArqueoDto,
} from '../dto/turnos.dto';
import { TurnosLogic } from '../logic/turnos.logic';

@ApiTags('Caja - Turnos, movimientos y arqueo')
@Controller('caja/turnos')
export class TurnosController {
  constructor(private readonly turnosLogic: TurnosLogic) {}

  @Get()
  @Permisos(PermisoBanderas.TURNOS_LISTAR)
  @ApiOperation({ summary: 'Historial de turnos con filtros' })
  listar(@Query() filtros: FiltroTurnosDto) {
    return this.turnosLogic.listar(filtros);
  }

  // Va antes de @Get(':id') porque Nest resuelve las rutas en orden de
  // declaración: si ':id' fuera primero, capturaría la palabra "abierto"
  // y el ParseIntPipe devolvería un 400.
  @Get('abierto/:idCajero')
  @Permisos(PermisoBanderas.TURNOS_VER)
  @ApiOperation({
    summary:
      'Turno abierto de un cajero. Devuelve registro = null si no tiene ninguno (no es error)',
  })
  obtenerAbierto(@Param('idCajero', ParseIntPipe) idCajero: number) {
    return this.turnosLogic.obtenerAbiertoPorCajero(idCajero);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.TURNOS_VER)
  @ApiOperation({ summary: 'Obtener turno con sus totales calculados' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.turnosLogic.obtenerPorId(id);
  }

  @Get(':id/resumen')
  @Permisos(PermisoBanderas.TURNOS_VER)
  @ApiOperation({
    summary: 'Resumen completo: totales por medio de pago, movimientos y arqueo',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  resumen(@Param('id', ParseIntPipe) id: number) {
    return this.turnosLogic.resumen(id);
  }

  @Get(':id/movimientos')
  @Permisos(PermisoBanderas.TURNOS_VER)
  @ApiOperation({ summary: 'Movimientos de caja del turno' })
  listarMovimientos(@Param('id', ParseIntPipe) id: number) {
    return this.turnosLogic.listarMovimientos(id);
  }

  @Post('abrir')
  @Permisos(PermisoBanderas.TURNOS_ABRIR)
  @ApiOperation({
    summary: 'Abrir turno (falla si la caja o el cajero ya tienen uno abierto)',
  })
  abrir(@Body() dto: AbrirTurnoDto) {
    return this.turnosLogic.abrir(dto);
  }

  @Post(':id/cerrar')
  @Permisos(PermisoBanderas.TURNOS_CERRAR)
  @ApiOperation({
    summary: 'Cerrar turno declarando el efectivo contado y guardar la diferencia',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  cerrar(@Param('id', ParseIntPipe) id: number, @Body() dto: CerrarTurnoDto) {
    return this.turnosLogic.cerrar(id, dto);
  }

  @Post(':id/movimientos')
  @Permisos(PermisoBanderas.TURNOS_MOVIMIENTOS)
  @ApiOperation({ summary: 'Registrar ingreso o egreso de caja' })
  registrarMovimiento(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: CreateMovimientoDto,
  ) {
    return this.turnosLogic.registrarMovimiento(id, dto);
  }

  @Post(':id/arqueo')
  @Permisos(PermisoBanderas.TURNOS_ARQUEO)
  @ApiOperation({
    summary: 'Guardar el conteo de billetes y monedas (reemplaza el anterior)',
  })
  guardarArqueo(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: GuardarArqueoDto,
  ) {
    return this.turnosLogic.guardarArqueo(id, dto);
  }

  @Delete('movimientos/:idMovimiento')
  @Permisos(PermisoBanderas.TURNOS_MOVIMIENTOS)
  @ApiOperation({
    summary: 'Anular un movimiento mal registrado (solo con el turno abierto)',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  anularMovimiento(
    @Param('idMovimiento', ParseIntPipe) idMovimiento: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.turnosLogic.anularMovimiento(idMovimiento, dto.idUsuarioAuditoria);
  }
}
