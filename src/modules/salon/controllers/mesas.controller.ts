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
import { CreateMesaDto, UpdateMesaDto, FiltroSalonDto } from '../dto/salon.dto';
import { SalonLogic } from '../logic/salon.logic';

type AuthRequest = Request & { user: AuthenticatedUser };

@ApiTags('Ambientes - mesas')
@Controller('salon/mesas')
export class MesasController {
  constructor(private readonly logic: SalonLogic) {}

  @Get()
  @Permisos(PermisoBanderas.AMBIENTES_LISTAR)
  @ApiOperation({ summary: 'Listar mesas con filtros y paginación' })
  listar(@Query() filtros: FiltroSalonDto) {
    return this.logic.listar('mesa', filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.AMBIENTES_LISTAR)
  @ApiOperation({ summary: 'Obtener mesa' })
  obtener(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtener('mesa', id);
  }

  @Post()
  @Permisos(PermisoBanderas.AMBIENTES_GESTIONAR)
  @ApiOperation({ summary: 'Crear mesa' })
  crear(@Body() dto: CreateMesaDto, @Req() req: AuthRequest) {
    return this.logic.guardar('mesa', null, dto, req.user.id);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.AMBIENTES_GESTIONAR)
  @ApiOperation({ summary: 'Editar mesa' })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateMesaDto,
    @Req() req: AuthRequest,
  ) {
    return this.logic.guardar('mesa', id, dto, req.user.id);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.AMBIENTES_GESTIONAR)
  @ApiOperation({ summary: 'Desactivar mesa (baja lógica)' })
  eliminar(@Param('id', ParseIntPipe) id: number, @Req() req: AuthRequest) {
    return this.logic.estado('mesa', id, 0, req.user.id);
  }

  @Patch(':id/activar')
  @Permisos(PermisoBanderas.AMBIENTES_GESTIONAR)
  @ApiOperation({ summary: 'Reactivar mesa' })
  activar(@Param('id', ParseIntPipe) id: number, @Req() req: AuthRequest) {
    return this.logic.estado('mesa', id, 1, req.user.id);
  }
}
