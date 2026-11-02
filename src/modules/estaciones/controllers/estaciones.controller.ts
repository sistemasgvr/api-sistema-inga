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
  CreateEstacionDto,
  FiltroEstacionesDto,
  UpdateEstacionDto,
} from '../dto/estaciones.dto';
import { EstacionesLogic } from '../logic/estaciones.logic';
import { UsuarioAuditoria } from '../../../common/decorators/usuario-auditoria.decorator';
import { SucursalSesion } from '../../../common/decorators/sesion-empresa.decorator';

@ApiTags('General - Estaciones')
@Controller('estaciones')
export class EstacionesController {
  constructor(private readonly estacionesLogic: EstacionesLogic) {}

  @Get()
  @Permisos(PermisoBanderas.ESTACIONES_LISTAR)
  @ApiOperation({ summary: 'Listar estaciones' })
  listar(
    @Query() filtros: FiltroEstacionesDto,
    @SucursalSesion() idSucursal: number,
  ) {
    return this.estacionesLogic.listar(
      Object.assign(filtros, { id_sucursal: idSucursal }),
    );
  }

  @Get(':id')
  @Permisos(PermisoBanderas.ESTACIONES_VER)
  @ApiOperation({ summary: 'Obtener estación por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(
    @Param('id', ParseIntPipe) id: number,
    @SucursalSesion() idSucursal: number,
  ) {
    return this.estacionesLogic.obtenerPorId(id, idSucursal);
  }

  @Post(':id/caja-principal')
  @Permisos(PermisoBanderas.ESTACIONES_EDITAR)
  principal(
    @Param('id', ParseIntPipe) id: number,
    @SucursalSesion() idSucursal: number,
  ) {
    return this.estacionesLogic.principal(id, idSucursal);
  }

  @Post()
  @Permisos(PermisoBanderas.ESTACIONES_CREAR)
  @ApiOperation({ summary: 'Crear estación' })
  crear(
    @Body() dto: CreateEstacionDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @SucursalSesion() idSucursal: number,
  ) {
    return this.estacionesLogic.crear({
      ...dto,
      id_sucursal: idSucursal,
      idUsuarioAuditoria,
    });
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.ESTACIONES_EDITAR)
  @ApiOperation({ summary: 'Actualizar estación' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateEstacionDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @SucursalSesion() idSucursal: number,
  ) {
    return this.estacionesLogic.actualizar(id, {
      ...dto,
      id_sucursal: idSucursal,
      idUsuarioAuditoria,
    });
  }

  @Patch(':id/activar')
  @Permisos(PermisoBanderas.ESTACIONES_ACTIVAR)
  @ApiOperation({ summary: 'Activar estación' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  activar(
    @Param('id', ParseIntPipe) id: number,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @SucursalSesion() idSucursal: number,
  ) {
    return this.estacionesLogic.activar(id, idUsuarioAuditoria, idSucursal);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.ESTACIONES_ELIMINAR)
  @ApiOperation({ summary: 'Dar de baja estación (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @SucursalSesion() idSucursal: number,
  ) {
    return this.estacionesLogic.eliminar(id, idUsuarioAuditoria, idSucursal);
  }
}
