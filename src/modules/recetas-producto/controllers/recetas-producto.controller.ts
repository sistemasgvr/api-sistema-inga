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
import { CreateRecetaDto, FiltroInsumosRecetaDto, GuardarRecetaInsumoDto } from '../dto/recetas-producto.dto';
import { RecetasProductoLogic } from '../logic/recetas-producto.logic';
import { UsuarioAuditoria } from '../../../common/decorators/usuario-auditoria.decorator';

@ApiTags('Productos - Recetas y Recetario')
@Controller('productos')
export class RecetasProductoController {
  constructor(private readonly recetasLogic: RecetasProductoLogic) {}

  @Get('insumos-procesados')
  @Permisos(PermisoBanderas.PRODUCTOS_LISTAR)
  @ApiOperation({
    summary:
      'Buscar insumos para el recetario: admite insumos crudos y platos con receta propia',
  })
  listarInsumosProcesados(@Query() filtros: FiltroInsumosRecetaDto) {
    return this.recetasLogic.listarInsumosProcesados(filtros);
  }

  @Get(':idProducto/recetas')
  @Permisos(PermisoBanderas.PRODUCTOS_VER)
  @ApiOperation({ summary: 'Listar historial de versiones de receta de un producto' })
  listarPorProducto(@Param('idProducto', ParseIntPipe) idProducto: number) {
    return this.recetasLogic.listarPorProducto(idProducto);
  }

  @Get('recetas/:id')
  @Permisos(PermisoBanderas.PRODUCTOS_VER)
  @ApiOperation({ summary: 'Obtener detalle completo de una receta con sus insumos' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.recetasLogic.obtenerPorId(id);
  }

  @Post(':idProducto/recetas')
  @Permisos(PermisoBanderas.PRODUCTOS_EDITAR)
  @ApiOperation({ summary: 'Crear nueva versión de receta para un producto' })
  crearReceta(
    @Param('idProducto', ParseIntPipe) idProducto: number,
    @Body() dto: CreateRecetaDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
  ) {
    return this.recetasLogic.crearReceta(idProducto, {
      ...dto,
      idUsuarioAuditoria,
    });
  }

  @Post('recetas/:idReceta/insumos')
  @Permisos(PermisoBanderas.PRODUCTOS_EDITAR)
  @ApiOperation({ summary: 'Agregar o actualizar un insumo dentro de una receta' })
  guardarInsumo(
    @Param('idReceta', ParseIntPipe) idReceta: number,
    @Body() dto: GuardarRecetaInsumoDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
  ) {
    return this.recetasLogic.guardarInsumo(idReceta, {
      ...dto,
      idUsuarioAuditoria,
    });
  }

  @Delete('recetas/insumos/:idInsumoReceta')
  @Permisos(PermisoBanderas.PRODUCTOS_EDITAR)
  @ApiOperation({ summary: 'Dar de baja un insumo de la receta' })
  eliminarInsumo(
    @Param('idInsumoReceta', ParseIntPipe) idInsumoReceta: number,
    @UsuarioAuditoria() idUsuarioAuditoria: number, 
  ) {
    return this.recetasLogic.eliminarInsumo(idInsumoReceta, idUsuarioAuditoria);
  }

  @Delete('recetas/:id')
  @Permisos(PermisoBanderas.PRODUCTOS_EDITAR)
  @ApiOperation({ summary: 'Dar de baja una receta completa' })
  eliminarReceta(
    @Param('id', ParseIntPipe) id: number,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
  ) {
    return this.recetasLogic.eliminarReceta(id, idUsuarioAuditoria);
  }
}