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
import { FiltroRolDto } from '../dto/filtros-rol.dto';
import { AsignarPermisosRolDto, AsignarRolesUsuarioDto, CreateRolDto, UpdateRolDto } from '../dto/roles.dto';
import { RolesLogic } from '../logic/roles.logic';

@ApiTags('Auth - Roles')
@Controller('auth/roles')
export class RolesController {
  constructor(private readonly rolesLogic: RolesLogic) {}

  @Get()
  @Permisos(PermisoBanderas.ROLES_LISTAR)
  @ApiOperation({ summary: 'Listar roles' })
  listar(@Query() filtros: FiltroRolDto) {
    return this.rolesLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.ROLES_VER)
  @ApiOperation({ summary: 'Obtener rol por ID con sus permisos' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.rolesLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.ROLES_CREAR)
  @ApiOperation({ summary: 'Crear rol' })
  crear(@Body() dto: CreateRolDto) {
    return this.rolesLogic.crear(dto);
  }

  @Patch(':id/activar')
  @Permisos(PermisoBanderas.ROLES_ACTIVAR)
  @ApiOperation({ summary: 'Activar rol' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  activar(@Param('id', ParseIntPipe) id: number) {
    return this.rolesLogic.activar(id);
  }

  @Patch(':id/permisos')
  @Permisos(PermisoBanderas.ROLES_EDITAR)
  @ApiOperation({ summary: 'Asignar matriz de permisos a un rol' })
  asignarPermisos(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AsignarPermisosRolDto,
  ) {
    return this.rolesLogic.asignarPermisos(id, dto);
  }

  @Patch('usuario/:idUsuario')
  @Permisos(PermisoBanderas.USUARIOS_EDITAR)
  @ApiOperation({ summary: 'Asignar roles a un usuario' })
  asignarRolesAUsuario(
    @Param('idUsuario', ParseIntPipe) idUsuario: number,
    @Body() dto: AsignarRolesUsuarioDto,
  ) {
    return this.rolesLogic.asignarRolesAUsuario(idUsuario, dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.ROLES_EDITAR)
  @ApiOperation({ summary: 'Actualizar rol' })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateRolDto,
  ) {
    return this.rolesLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.ROLES_ELIMINAR)
  @ApiOperation({ summary: 'Desactivar rol (baja lógica)' })
  desactivar(@Param('id', ParseIntPipe) id: number) {
    return this.rolesLogic.eliminar(id);
  }
}