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

type AuthRequest = Request & { user: AuthenticatedUser };

@ApiTags('Ambientes - salones')
@Controller('salon/salones')
export class SalonesController {
  constructor(private readonly logic: SalonLogic) {}

  @Get('sucursales')
  @Permisos(PermisoBanderas.AMBIENTES_LISTAR)
  @ApiOperation({ summary: 'Sucursales activas para el selector de ambientes' })
  sucursales() {
    return this.logic.sucursales();
  }

  @Get()
  @Permisos(PermisoBanderas.AMBIENTES_LISTAR)
  @ApiOperation({ summary: 'Listar salones con filtros y paginación' })
  listar(@Query() filtros: FiltroSalonDto) {
    return this.logic.listar('salon', filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.AMBIENTES_LISTAR)
  @ApiOperation({ summary: 'Obtener salon' })
  obtener(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtener('salon', id);
  }

  @Post()
  @Permisos(PermisoBanderas.AMBIENTES_GESTIONAR)
  @ApiOperation({ summary: 'Crear salon' })
  crear(@Body() dto: CreateSalonDto, @Req() req: AuthRequest) {
    return this.logic.guardar('salon', null, dto, req.user.id);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.AMBIENTES_GESTIONAR)
  @ApiOperation({ summary: 'Editar salon' })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateSalonDto,
    @Req() req: AuthRequest,
  ) {
    return this.logic.guardar('salon', id, dto, req.user.id);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.AMBIENTES_GESTIONAR)
  @ApiOperation({ summary: 'Desactivar salon (baja lógica)' })
  eliminar(@Param('id', ParseIntPipe) id: number, @Req() req: AuthRequest) {
    return this.logic.estado('salon', id, 0, req.user.id);
  }

  @Patch(':id/activar')
  @Permisos(PermisoBanderas.AMBIENTES_GESTIONAR)
  @ApiOperation({ summary: 'Reactivar salon' })
  activar(@Param('id', ParseIntPipe) id: number, @Req() req: AuthRequest) {
    return this.logic.estado('salon', id, 1, req.user.id);
  }
}
