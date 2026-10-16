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
import {
  ApiForbiddenResponse,
  ApiNotFoundResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import {
  AbrirTurnoDto,
  CerrarTurnoDto,
  CreateMovimientoDto,
  FiltroTurnosDto,
  GuardarArqueoDto,
} from '../dto/turnos.dto';
import { TurnosLogic } from '../logic/turnos.logic';
import { UsuarioAuditoria } from '../../../common/decorators/usuario-auditoria.decorator';

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

  // También antes de ':id', por la misma razón.
  // Sin permiso específico (solo sesión): la alerta de caja abierta se muestra a
  // todos los usuarios y los módulos que pagan o cobran la consultan aunque el
  // usuario no tenga turnos.ver.
  @Get('vigente')
  @ApiOperation({
    summary:
      'Caja abierta contra la que se registran cobros, pagos y gastos. Prefiere el turno del usuario; registro = null si no hay ninguna',
  })
  obtenerVigente(
    @UsuarioAuditoria() idUsuario: number,
    @Query('id_sucursal') idSucursal?: string,
  ) {
    return this.turnosLogic.obtenerVigente(
      idUsuario,
      idSucursal ? Number(idSucursal) : null,
    );
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
  abrir(
    @Body() dto: AbrirTurnoDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
  ) {
    return this.turnosLogic.abrir({ ...dto, idUsuarioAuditoria });
  }

  @Post(':id/cerrar')
  @Permisos(PermisoBanderas.TURNOS_CERRAR)
  @ApiOperation({
    summary: 'Cerrar turno declarando el efectivo contado y guardar la diferencia',
    description:
      'Solo el cajero que abrió la caja o un administrador (rol ADMIN o superadministrador) puede cerrarla.',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  @ApiForbiddenResponse({
    type: () => ApiErrorResponseDto,
    description: 'El usuario no abrió la caja y no es administrador',
  })
  cerrar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: CerrarTurnoDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
  ) {
    return this.turnosLogic.cerrar(id, { ...dto, idUsuarioAuditoria });
  }

  @Post(':id/movimientos')
  @Permisos(PermisoBanderas.TURNOS_MOVIMIENTOS)
  @ApiOperation({ summary: 'Registrar ingreso o egreso de caja' })
  registrarMovimiento(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: CreateMovimientoDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
  ) {
    return this.turnosLogic.registrarMovimiento(id, {
      ...dto,
      idUsuarioAuditoria,
    });
  }

  @Post(':id/arqueo')
  @Permisos(PermisoBanderas.TURNOS_ARQUEO)
  @ApiOperation({
    summary: 'Guardar el conteo de billetes y monedas (reemplaza el anterior)',
    description:
      'Es parte del cierre: con la caja abierta, solo el cajero que la abrió o un administrador.',
  })
  @ApiForbiddenResponse({ type: () => ApiErrorResponseDto })
  guardarArqueo(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: GuardarArqueoDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
  ) {
    return this.turnosLogic.guardarArqueo(id, { ...dto, idUsuarioAuditoria });
  }

  @Delete('movimientos/:idMovimiento')
  @Permisos(PermisoBanderas.TURNOS_MOVIMIENTOS)
  @ApiOperation({
    summary: 'Anular un movimiento mal registrado (solo con el turno abierto)',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  anularMovimiento(
    @Param('idMovimiento', ParseIntPipe) idMovimiento: number,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
  ) {
    return this.turnosLogic.anularMovimiento(idMovimiento, idUsuarioAuditoria);
  }
}
