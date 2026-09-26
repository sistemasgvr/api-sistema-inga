import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Put,
  Req,
} from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import type { AuthenticatedUser } from '../../../common/interfaces/authenticated-user.interface';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { PermisoBanderas as P } from '../../../common/constants/permiso-banderas';
import {
  AbrirPedidoDto,
  AgregarItemDto,
  AnularPedidoDto,
  EditarItemDto,
  EstadoPedidoDto,
} from '../dto/pedido.dto';
import { PedidoLogic } from '../logic/pedido.logic';

type AuthRequest = Request & { user: AuthenticatedUser };

@ApiTags('Pedidos')
@Controller('pedidos')
export class PedidosController {
  constructor(private readonly logic: PedidoLogic) {}

  @Get(':id')
  @Permisos(P.PEDIDOS_VER)
  @ApiOperation({ summary: 'Consultar pedido, ítems, adicionales y comandas' })
  obtener(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtener(id);
  }

  @Post()
  @Permisos(P.PEDIDOS_ABRIR)
  @ApiOperation({ summary: 'Abrir pedido y ocupar su mesa' })
  abrir(@Body() dto: AbrirPedidoDto, @Req() req: AuthRequest) {
    return this.logic.ejecutar('abrir', null, null, dto, req.user);
  }

  @Post(':id/items')
  @Permisos(P.PEDIDOS_EDITAR)
  @ApiOperation({ summary: 'Agregar producto, receta y adicionales' })
  agregar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AgregarItemDto,
    @Req() req: AuthRequest,
  ) {
    return this.logic.ejecutar('agregar_item', id, null, dto, req.user);
  }

  @Put(':id/items/:item_id')
  @Permisos(P.PEDIDOS_EDITAR)
  @ApiOperation({
    summary: 'Editar cantidad u observación de un ítem pendiente',
  })
  editar(
    @Param('id', ParseIntPipe) id: number,
    @Param('item_id', ParseIntPipe) item: number,
    @Body() dto: EditarItemDto,
    @Req() req: AuthRequest,
  ) {
    return this.logic.ejecutar('editar_item', id, item, dto, req.user);
  }

  @Delete(':id/items/:item_id')
  @Permisos(P.PEDIDOS_ANULAR)
  @ApiOperation({
    summary: 'Anular ítem no comandado, con motivo y autorización',
  })
  anularItem(
    @Param('id', ParseIntPipe) id: number,
    @Param('item_id', ParseIntPipe) item: number,
    @Body() dto: AnularPedidoDto,
    @Req() req: AuthRequest,
  ) {
    return this.logic.ejecutar('anular_item', id, item, dto, req.user);
  }

  @Post(':id/comandar')
  @Permisos(P.PEDIDOS_COMANDAR)
  @ApiOperation({
    summary: 'Comandar ítems pendientes por estación y descontar inventario',
  })
  comandar(@Param('id', ParseIntPipe) id: number, @Req() req: AuthRequest) {
    return this.logic.ejecutar('comandar', id, null, {}, req.user);
  }

  @Put(':id/estado')
  @Permisos(P.PEDIDOS_ESTADO)
  @ApiOperation({
    summary:
      'Aplicar una transición válida con sus efectos sobre mesa e inventario',
  })
  estado(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: EstadoPedidoDto,
    @Req() req: AuthRequest,
  ) {
    return this.logic.ejecutar('estado', id, null, dto, req.user);
  }

  @Post(':id/anular')
  @Permisos(P.PEDIDOS_ANULAR)
  @ApiOperation({
    summary: 'Anular pedido y devolver las cantidades del kardex original',
  })
  anular(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AnularPedidoDto,
    @Req() req: AuthRequest,
  ) {
    return this.logic.ejecutar('anular', id, null, dto, req.user);
  }
}
