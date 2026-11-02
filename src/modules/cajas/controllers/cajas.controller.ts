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
import { CreateCajaDto, FiltroCajasDto, UpdateCajaDto } from '../dto/cajas.dto';
import { CajasLogic } from '../logic/cajas.logic';
import { UsuarioAuditoria } from '../../../common/decorators/usuario-auditoria.decorator';
import { SucursalSesion } from '../../../common/decorators/sesion-empresa.decorator';

@ApiTags('Caja - Cajas físicas')
@Controller('caja/cajas')
export class CajasController {
  constructor(private readonly cajasLogic: CajasLogic) {}

  @Get()
  @Permisos(PermisoBanderas.CAJAS_LISTAR)
  @ApiOperation({
    summary: 'Listar cajas (incluye si tienen un turno abierto y de quién)',
  })
  listar(
    @Query() filtros: FiltroCajasDto,
    @SucursalSesion() idSucursal: number,
  ) {
    return this.cajasLogic.listar(
      Object.assign(filtros, { id_sucursal: idSucursal }),
    );
  }

  @Get(':id')
  @Permisos(PermisoBanderas.CAJAS_VER)
  @ApiOperation({ summary: 'Obtener caja por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(
    @Param('id', ParseIntPipe) id: number,
    @SucursalSesion() idSucursal: number,
  ) {
    return this.cajasLogic.obtenerPorId(id, idSucursal);
  }

  @Post()
  @Permisos(PermisoBanderas.CAJAS_CREAR)
  @ApiOperation({ summary: 'Crear caja física' })
  crear(
    @Body() dto: CreateCajaDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @SucursalSesion() idSucursal: number,
  ) {
    return this.cajasLogic.crear({
      ...dto,
      id_sucursal: idSucursal,
      idUsuarioAuditoria,
    });
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.CAJAS_EDITAR)
  @ApiOperation({ summary: 'Actualizar caja' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateCajaDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @SucursalSesion() idSucursal: number,
  ) {
    return this.cajasLogic.actualizar(id, {
      ...dto,
      id_sucursal: idSucursal,
      idUsuarioAuditoria,
    });
  }

  @Patch(':id/activar')
  @Permisos(PermisoBanderas.CAJAS_ACTIVAR)
  @ApiOperation({ summary: 'Reactivar caja' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  activar(
    @Param('id', ParseIntPipe) id: number,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @SucursalSesion() idSucursal: number,
  ) {
    return this.cajasLogic.activar(id, idUsuarioAuditoria, idSucursal);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.CAJAS_ELIMINAR)
  @ApiOperation({
    summary: 'Dar de baja caja (falla si tiene un turno abierto)',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @SucursalSesion() idSucursal: number,
  ) {
    return this.cajasLogic.eliminar(id, idUsuarioAuditoria, idSucursal);
  }
}
