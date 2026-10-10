import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Put,
  Query,
  Req,
} from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import type { AuthenticatedUser } from '../../../common/interfaces/authenticated-user.interface';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { PermisoBanderas as P } from '../../../common/constants/permiso-banderas';
import {
  EntregarItemDto, PreparacionItemDto,
  PrecuentaPedidoDto, CobrarPedidoDto, CreditoPedidoDto,
  AbrirPedidoDto,
  AgregarItemDto,
  AnularPedidoDto,
  EditarItemDto,
  EstadoPedidoDto,
  FiltroPedidoDto,
} from '../dto/pedido.dto';
import { PedidoLogic } from '../logic/pedido.logic';

type AuthRequest = Request & { user: AuthenticatedUser };

@ApiTags('Pedidos')
@Controller('pedidos')
export class PedidosController {
  constructor(private readonly logic: PedidoLogic) {}

  @Post(':id/precuenta') @Permisos(P.PEDIDOS_ESTADO)
  precuenta(@Param('id',ParseIntPipe) id:number,@Body() dto:PrecuentaPedidoDto,@Req() req:AuthRequest) {
    return this.logic.ejecutar('precuenta',id,null,dto,req.user);
  }
  @Post(':id/cobrar') @Permisos(P.PEDIDOS_ESTADO)
  cobrar(@Param('id',ParseIntPipe) id:number,@Body() dto:CobrarPedidoDto,@Req() req:AuthRequest) {
    return this.logic.ejecutar('cobrar',id,null,dto,req.user);
  }
  @Post(':id/credito') @Permisos(P.PEDIDOS_ESTADO)
  credito(@Param('id',ParseIntPipe) id:number,@Body() dto:CreditoPedidoDto,@Req() req:AuthRequest) {
    return this.logic.ejecutar('credito',id,null,dto,req.user);
  }

  @Get()
  @Permisos(P.PEDIDOS_VER)
  @ApiOperation({ summary: 'Listar pedidos con filtros y paginación' })
  listar(@Query() filtros: FiltroPedidoDto) {
    return this.logic.listar(filtros);
  }

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
    summary: 'Cancelar unidades no entregadas con motivo y autorización',
  })
  anularItem(
    @Param('id', ParseIntPipe) id: number,
    @Param('item_id', ParseIntPipe) item: number,
    @Body() dto: AnularPedidoDto,
    @Req() req: AuthRequest,
  ) {
    return this.logic.ejecutar('anular_item', id, item, dto, req.user);
  }

  @Put(':id/items/:item_id/preparacion') @Permisos(P.PRODUCCION_PREPARAR)
  preparacion(@Param('id',ParseIntPipe) id:number,@Param('item_id',ParseIntPipe) item:number,
    @Body() dto:PreparacionItemDto,@Req() req:AuthRequest) {
      return this.logic.ejecutar('preparacion',id,item,dto,req.user);
  }
  @Post(':id/items/:item_id/entregar')
  @Permisos(P.PEDIDOS_ENTREGAR)
  @ApiOperation({
    summary: 'Entregar una cantidad acumulada del producto terminado',
  })
  entregar(
    @Param('id', ParseIntPipe) id: number,
    @Param('item_id', ParseIntPipe) item: number,
    @Body() dto: EntregarItemDto,
    @Req() req: AuthRequest,
  ) {
    return this.logic.ejecutar('entregar', id, item, dto, req.user);
  }

  @Post(':id/comandar')
  @Permisos(P.PEDIDOS_COMANDAR)
  @ApiOperation({
    summary: 'Comandar ítems y reservar productos terminados disponibles',
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
    summary:
      'Anular pedido sin entregas, liberando reservas o registrando merma',
  })
  anular(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AnularPedidoDto,
    @Req() req: AuthRequest,
  ) {
    return this.logic.ejecutar('anular', id, null, dto, req.user);
  }

  @Post(':id/descartar')
  @Permisos(P.PEDIDOS_ABRIR)
  @ApiOperation({
    summary: 'Descartar un pedido abierto sin productos (solo quien lo abrió)',
  })
  descartar(@Param('id', ParseIntPipe) id: number, @Req() req: AuthRequest) {
    return this.logic.ejecutar('descartar', id, null, {}, req.user);
  }
}
