import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Query,
  Req,
} from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import type { AuthenticatedUser } from '../../../common/interfaces/authenticated-user.interface';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { PermisoBanderas as P } from '../../../common/constants/permiso-banderas';
import {
  FiltroInventarioDto, DisponibilidadDto, CocinaFiltroDto, AvisosCocinaFiltroDto,
  MovimientoDto,
  PrepararDto,
} from '../dto/inventario.dto';
import { InventarioLogic } from '../logic/inventario.logic';
type AuthRequest = Request & { user: AuthenticatedUser };

@ApiTags('Inventario')
@Controller('inventario')
export class InventarioController {
  constructor(private readonly logic: InventarioLogic) {}

  @Get('productos-preparables') @Permisos(P.PRODUCCION_PREPARAR)
  productosPreparables(@Query('id_sucursal', ParseIntPipe) sucursal:number) { return this.logic.productosPreparables(sucursal); }
  @Get('disponibilidad') @Permisos(P.PRODUCCION_PREPARAR)
  disponibilidad(@Query() f: DisponibilidadDto) { return this.logic.disponibilidad(f); }
  @Get('cocina') @Permisos(P.PRODUCCION_PREPARAR)
  cocina(@Query() f: CocinaFiltroDto) { return this.logic.cocina(f); }
  @Get('cocina/avisos') @Permisos(P.PRODUCCION_PREPARAR)
  @ApiOperation({ summary: 'Comandas rechazadas por falta de insumos, pendientes de atender.' })
  avisos(@Query() f: AvisosCocinaFiltroDto) { return this.logic.avisos(f); }
  @Post('cocina/avisos/:id/atender') @Permisos(P.PRODUCCION_PREPARAR)
  atenderAviso(@Param('id', ParseIntPipe) id: number, @Req() req: AuthRequest) {
    return this.logic.atenderAviso(id, req.user.id);
  }
  @Get('stock')
  @Permisos(P.INVENTARIO_VER)
  stock(@Query() filtros: FiltroInventarioDto) {
    return this.logic.listar('stock', filtros);
  }

  @Get('kardex')
  @Permisos(P.INVENTARIO_VER)
  kardex(@Query() filtros: FiltroInventarioDto) {
    return this.logic.listar('kardex', filtros);
  }

  @Get('movimientos/:id')
  @Permisos(P.INVENTARIO_VER)
  obtener(@Param('id', ParseIntPipe) id: number) {
    return this.logic.movimiento(id);
  }

  @Post('movimientos')
  @Permisos(P.INVENTARIO_GESTIONAR)
  registrar(@Body() dto: MovimientoDto, @Req() req: AuthRequest) {
    return this.logic.ejecutar('alm_registrar', dto, req.user.id);
  }

  @Post('movimientos/:id/confirmar')
  @Permisos(P.INVENTARIO_GESTIONAR)
  confirmar(@Param('id', ParseIntPipe) id: number, @Req() req: AuthRequest) {
    return this.logic.ejecutar('alm_confirmar', id, req.user.id);
  }

  @Post('movimientos/:id/cancelar')
  @Permisos(P.INVENTARIO_GESTIONAR)
  cancelar(@Param('id', ParseIntPipe) id: number, @Req() req: AuthRequest) {
    return this.logic.ejecutar('alm_cancelar', id, req.user.id);
  }

  @Post('preparaciones')
  @Permisos(P.PRODUCCION_PREPARAR)
  @ApiOperation({
    summary:
      'Confirmar preparación terminada: consume ingredientes e ingresa platos; reserva si pertenece a pedido.',
  })
  preparar(@Body() dto: PrepararDto, @Req() req: AuthRequest) {
    return this.logic.ejecutar('prod_preparar', dto, req.user.id);
  }
}
