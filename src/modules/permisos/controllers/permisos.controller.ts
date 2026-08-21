import { Controller, Get, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { FiltroPermisoDto } from '../dto/filtros-permiso.dto';
import { PermisosLogic } from '../logic/permisos.logic';

@ApiTags('Auth - Permisos')
@Controller('auth/permisos')
export class PermisosController {
  constructor(private readonly permisosLogic: PermisosLogic) {}

  @Get()
  @Permisos(PermisoBanderas.ROLES_VER)
  @ApiOperation({ summary: 'Listar catálogo de permisos disponible' })
  listar(@Query() filtros: FiltroPermisoDto) {
    return this.permisosLogic.listar(filtros);
  }
}