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
  Req,
} from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import type { AuthenticatedUser } from '../../../common/interfaces/authenticated-user.interface';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import {
  CreateSalonDto,
  UpdateSalonDto,
  FiltroSalonDto,
} from '../dto/salon.dto';
import { SalonLogic } from '../logic/salon.logic';
import {
  SucursalSesion,
  sucursalDe,
} from '../../../common/decorators/sesion-empresa.decorator';

type AuthRequest = Request & { user: AuthenticatedUser };

@ApiTags('Ambientes - salones')
@Controller('salon/salones')
export class SalonesController {
  constructor(private readonly logic: SalonLogic) {}

  @Get('sucursales')
  @Permisos(PermisoBanderas.AMBIENTES_LISTAR)
  @ApiOperation({ summary: 'Sucursales activas para el selector de ambientes' })
  sucursales(@SucursalSesion() idSucursal: number) {
    return this.logic.sucursales(idSucursal);
  }

  @Get()
  @Permisos(PermisoBanderas.AMBIENTES_LISTAR)
  @ApiOperation({ summary: 'Listar salones con filtros y paginación' })
  listar(
    @Query() filtros: FiltroSalonDto,
    @SucursalSesion() idSucursal: number,
  ) {
    return this.logic.listar('salon', filtros, idSucursal);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.AMBIENTES_LISTAR)
  @ApiOperation({ summary: 'Obtener salon' })
  obtener(
    @Param('id', ParseIntPipe) id: number,
    @SucursalSesion() idSucursal: number,
  ) {
    return this.logic.obtener('salon', id, idSucursal);
  }

  @Post()
  @Permisos(PermisoBanderas.AMBIENTES_GESTIONAR)
  @ApiOperation({ summary: 'Crear salon' })
  crear(@Body() dto: CreateSalonDto, @Req() req: AuthRequest) {
    return this.logic.guardar(
      'salon',
      null,
      dto,
      req.user.id,
      sucursalDe(req.user),
    );
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.AMBIENTES_GESTIONAR)
  @ApiOperation({ summary: 'Editar salon' })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateSalonDto,
    @Req() req: AuthRequest,
  ) {
    return this.logic.guardar(
      'salon',
      id,
      dto,
      req.user.id,
      sucursalDe(req.user),
    );
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.AMBIENTES_GESTIONAR)
  @ApiOperation({ summary: 'Desactivar salon (baja lógica)' })
  eliminar(@Param('id', ParseIntPipe) id: number, @Req() req: AuthRequest) {
    return this.logic.estado('salon', id, 0, req.user.id, sucursalDe(req.user));
  }

  @Patch(':id/activar')
  @Permisos(PermisoBanderas.AMBIENTES_GESTIONAR)
  @ApiOperation({ summary: 'Reactivar salon' })
  activar(@Param('id', ParseIntPipe) id: number, @Req() req: AuthRequest) {
    return this.logic.estado('salon', id, 1, req.user.id, sucursalDe(req.user));
  }
}
