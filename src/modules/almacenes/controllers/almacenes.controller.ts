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
  CreateAlmacenDto,
  FiltroAlmacenesDto,
  UpdateAlmacenDto,
} from '../dto/almacenes.dto';
import { AlmacenesLogic } from '../logic/almacenes.logic';

@ApiTags('General - Almacenes')
@Controller('almacenes')
export class AlmacenesController {
  constructor(private readonly almacenLogic: AlmacenesLogic) {}

  @Get()
  @Permisos(PermisoBanderas.ALMACENES_LISTAR) 
  @ApiOperation({ summary: 'Listar almacenes' })
  listar(@Query() filtros: FiltroAlmacenesDto) {
    return this.almacenLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.ALMACENES_VER)
  @ApiOperation({ summary: 'Obtener almacén por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.almacenLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.ALMACENES_CREAR)
  @ApiOperation({ summary: 'Crear almacén' })
  crear(@Body() dto: CreateAlmacenDto) {
    return this.almacenLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.ALMACENES_EDITAR)
  @ApiOperation({ summary: 'Actualizar almacén' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateAlmacenDto,
  ) {
    return this.almacenLogic.actualizar(id, dto);
  }

  @Patch(':id/activar')
  @Permisos(PermisoBanderas.ALMACENES_ACTIVAR)
  @ApiOperation({ summary: 'Activar almacén' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  activar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.almacenLogic.activar(id, dto.idUsuarioAuditoria);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.ALMACENES_ELIMINAR)
  @ApiOperation({ summary: 'Dar de baja almacén (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.almacenLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}