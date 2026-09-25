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
  CreateSubCategoriaProductoDto,
  FiltroSubCategoriasProductoDto,
  UpdateSubCategoriaProductoDto,
} from '../dto/subcategorias-producto.dto';
import { SubCategoriasProductoLogic } from '../logic/subcategorias-producto.logic';

@ApiTags('Productos - Subcategorías')
@Controller('productos/subcategorias')
export class SubCategoriasProductoController {
  constructor(private readonly subCategoriasLogic: SubCategoriasProductoLogic) {}

  @Get()
  @Permisos(PermisoBanderas.SUBCATEGORIAS_LISTAR)
  @ApiOperation({ summary: 'Listar subcategorías de producto' })
  listar(@Query() filtros: FiltroSubCategoriasProductoDto) {
    return this.subCategoriasLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.SUBCATEGORIAS_VER)
  @ApiOperation({ summary: 'Obtener subcategoría por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.subCategoriasLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.SUBCATEGORIAS_CREAR)
  @ApiOperation({ summary: 'Crear subcategoría de producto' })
  crear(@Body() dto: CreateSubCategoriaProductoDto) {
    return this.subCategoriasLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.SUBCATEGORIAS_EDITAR)
  @ApiOperation({ summary: 'Actualizar subcategoría de producto' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateSubCategoriaProductoDto,
  ) {
    return this.subCategoriasLogic.actualizar(id, dto);
  }

  @Patch(':id/activar')
  @Permisos(PermisoBanderas.SUBCATEGORIAS_ACTIVAR)
  @ApiOperation({ summary: 'Activar subcategoría de producto' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  activar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.subCategoriasLogic.activar(id, dto.idUsuarioAuditoria);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.SUBCATEGORIAS_ELIMINAR)
  @ApiOperation({ summary: 'Desactivar subcategoría (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.subCategoriasLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}