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
import {
  CreateAlmacenDto,
  FiltroAlmacenesDto,
  UpdateAlmacenDto,
} from '../dto/almacenes.dto';
import { AlmacenesLogic } from '../logic/almacenes.logic';
import { UsuarioAuditoria } from '../../../common/decorators/usuario-auditoria.decorator';
import { SucursalSesion } from '../../../common/decorators/sesion-empresa.decorator';

@ApiTags('General - Almacenes')
@Controller('almacenes')
export class AlmacenesController {
  constructor(private readonly almacenLogic: AlmacenesLogic) {}

  @Get()
  @Permisos(PermisoBanderas.ALMACENES_LISTAR)
  @ApiOperation({ summary: 'Listar almacenes' })
  listar(
    @Query() filtros: FiltroAlmacenesDto,
    @SucursalSesion() idSucursal: number,
  ) {
    return this.almacenLogic.listar(
      Object.assign(filtros, { id_sucursal: idSucursal }),
    );
  }

  @Get(':id')
  @Permisos(PermisoBanderas.ALMACENES_VER)
  @ApiOperation({ summary: 'Obtener almacén por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(
    @Param('id', ParseIntPipe) id: number,
    @SucursalSesion() idSucursal: number,
  ) {
    return this.almacenLogic.obtenerPorId(id, idSucursal);
  }

  @Post()
  @Permisos(PermisoBanderas.ALMACENES_CREAR)
  @ApiOperation({ summary: 'Crear almacén' })
  crear(
    @Body() dto: CreateAlmacenDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @SucursalSesion() idSucursal: number,
  ) {
    return this.almacenLogic.crear({
      ...dto,
      id_sucursal: idSucursal,
      idUsuarioAuditoria,
    });
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.ALMACENES_EDITAR)
  @ApiOperation({ summary: 'Actualizar almacén' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateAlmacenDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @SucursalSesion() idSucursal: number,
  ) {
    return this.almacenLogic.actualizar(id, {
      ...dto,
      id_sucursal: idSucursal,
      idUsuarioAuditoria,
    });
  }

  @Patch(':id/activar')
  @Permisos(PermisoBanderas.ALMACENES_ACTIVAR)
  @ApiOperation({ summary: 'Activar almacén' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  activar(
    @Param('id', ParseIntPipe) id: number,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @SucursalSesion() idSucursal: number,
  ) {
    return this.almacenLogic.activar(id, idUsuarioAuditoria, idSucursal);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.ALMACENES_ELIMINAR)
  @ApiOperation({ summary: 'Dar de baja almacén (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @SucursalSesion() idSucursal: number,
  ) {
    return this.almacenLogic.eliminar(id, idUsuarioAuditoria, idSucursal);
  }
}
