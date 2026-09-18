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
import { CreateCajaDto, FiltroCajasDto, UpdateCajaDto } from '../dto/cajas.dto';
import { CajasLogic } from '../logic/cajas.logic';

@ApiTags('Caja - Cajas físicas')
@Controller('caja/cajas')
export class CajasController {
  constructor(private readonly cajasLogic: CajasLogic) {}

  @Get()
  @Permisos(PermisoBanderas.CAJAS_LISTAR)
  @ApiOperation({
    summary: 'Listar cajas (incluye si tienen un turno abierto y de quién)',
  })
  listar(@Query() filtros: FiltroCajasDto) {
    return this.cajasLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.CAJAS_VER)
  @ApiOperation({ summary: 'Obtener caja por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.cajasLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.CAJAS_CREAR)
  @ApiOperation({ summary: 'Crear caja física' })
  crear(@Body() dto: CreateCajaDto) {
    return this.cajasLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.CAJAS_EDITAR)
  @ApiOperation({ summary: 'Actualizar caja' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateCajaDto,
  ) {
    return this.cajasLogic.actualizar(id, dto);
  }

  @Patch(':id/activar')
  @Permisos(PermisoBanderas.CAJAS_ACTIVAR)
  @ApiOperation({ summary: 'Reactivar caja' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  activar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.cajasLogic.activar(id, dto.idUsuarioAuditoria);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.CAJAS_ELIMINAR)
  @ApiOperation({
    summary: 'Dar de baja caja (falla si tiene un turno abierto)',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.cajasLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
