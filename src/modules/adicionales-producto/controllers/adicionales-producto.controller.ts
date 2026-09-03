import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
} from '@nestjs/common';
import { ApiNotFoundResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { CreateAdicionalDto, UpdateAdicionalDto } from '../dto/adicionales-producto.dto';
import { AdicionalesProductoLogic } from '../logic/adicionales-producto.logic';

@ApiTags('Productos - Adicionales')
@Controller('productos')
export class AdicionalesProductoController {
  constructor(private readonly adicionalesLogic: AdicionalesProductoLogic) {}

  @Get(':idProducto/adicionales')
  @Permisos(PermisoBanderas.PRODUCTOS_VER)
  @ApiOperation({ summary: 'Listar adicionales asociados a un producto' })
  listarPorProducto(@Param('idProducto', ParseIntPipe) idProducto: number) {
    return this.adicionalesLogic.listarPorProducto(idProducto);
  }

  @Get('adicionales/:id')
  @Permisos(PermisoBanderas.PRODUCTOS_VER)
  @ApiOperation({ summary: 'Obtener adicional por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.adicionalesLogic.obtenerPorId(id);
  }

  @Post(':idProducto/adicionales')
  @Permisos(PermisoBanderas.PRODUCTOS_EDITAR)
  @ApiOperation({ summary: 'Crear adicional para un producto' })
  crear(
    @Param('idProducto', ParseIntPipe) idProducto: number,
    @Body() dto: CreateAdicionalDto,
  ) {
    return this.adicionalesLogic.crear(idProducto, dto);
  }

  @Patch('adicionales/:id')
  @Permisos(PermisoBanderas.PRODUCTOS_EDITAR)
  @ApiOperation({ summary: 'Actualizar adicional' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateAdicionalDto,
  ) {
    return this.adicionalesLogic.actualizar(id, dto);
  }

  @Delete('adicionales/:id')
  @Permisos(PermisoBanderas.PRODUCTOS_EDITAR)
  @ApiOperation({ summary: 'Dar de baja un adicional' })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.adicionalesLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}