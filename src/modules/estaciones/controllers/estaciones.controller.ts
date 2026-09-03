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
  CreateEstacionDto,
  FiltroEstacionesDto,
  UpdateEstacionDto,
} from '../dto/estaciones.dto';
import { EstacionesLogic } from '../logic/estaciones.logic';

@ApiTags('General - Estaciones')
@Controller('estaciones')
export class EstacionesController {
  constructor(private readonly estacionesLogic: EstacionesLogic) {}

  @Get()
  @Permisos(PermisoBanderas.ESTACIONES_LISTAR)
  @ApiOperation({ summary: 'Listar estaciones' })
  listar(@Query() filtros: FiltroEstacionesDto) {
    return this.estacionesLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.ESTACIONES_VER)
  @ApiOperation({ summary: 'Obtener estación por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.estacionesLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.ESTACIONES_CREAR)
  @ApiOperation({ summary: 'Crear estación' })
  crear(@Body() dto: CreateEstacionDto) {
    return this.estacionesLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.ESTACIONES_EDITAR)
  @ApiOperation({ summary: 'Actualizar estación' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateEstacionDto,
  ) {
    return this.estacionesLogic.actualizar(id, dto);
  }

  @Patch(':id/activar')
  @Permisos(PermisoBanderas.ESTACIONES_ACTIVAR)
  @ApiOperation({ summary: 'Activar estación' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  activar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.estacionesLogic.activar(id, dto.idUsuarioAuditoria);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.ESTACIONES_ELIMINAR)
  @ApiOperation({ summary: 'Dar de baja estación (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.estacionesLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}