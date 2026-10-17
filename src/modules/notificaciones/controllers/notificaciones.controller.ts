import { Controller, Get, Patch, Param, Body, Post, Req } from '@nestjs/common';
import { Request } from 'express';
import { AuthenticatedUser } from '../../../common/interfaces/authenticated-user.interface';
import { NotificacionesLogic } from '../logic/notificaciones.logic';
import { CrearNotificacionDto } from '../dto/crear-notificacion.dto';

@Controller('notificaciones')
export class NotificacionesController {
  constructor(private readonly logic: NotificacionesLogic) {}

  @Get()
  listar(@Req() req: Request & { user: AuthenticatedUser }) {
    return this.logic.listarParaUsuario(req.user);
  }

  @Get('no-leidas/count')
  contar(@Req() req: Request & { user: AuthenticatedUser }) {
    return this.logic.contarParaUsuario(req.user);
  }

  @Patch(':id/leer')
  leer(@Param('id') id: string, @Req() req: Request & { user: AuthenticatedUser }) {
    return this.logic.marcarLeida(id, req.user);
  }

  @Post()
  crear(@Body() dto: CrearNotificacionDto) {
    return this.logic.emitir(dto);
  }
}
