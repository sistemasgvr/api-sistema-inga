import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  Req,
} from '@nestjs/common';
import { Request } from 'express';
import { AuthenticatedUser } from '../../../common/interfaces/authenticated-user.interface';
import { NotificacionesLogic } from '../logic/notificaciones.logic';
import { CrearNotificacionDto } from '../dto/crear-notificacion.dto';
import {
  ListarNotificacionesDto,
  MarcarTodasLeidasDto,
} from '../dto/listar-notificaciones.dto';

type RequestConUsuario = Request & { user: AuthenticatedUser };

@Controller('notificaciones')
export class NotificacionesController {
  constructor(private readonly logic: NotificacionesLogic) {}

  @Get()
  listar(
    @Query() filtros: ListarNotificacionesDto,
    @Req() req: RequestConUsuario,
  ) {
    return this.logic.listarParaUsuario(req.user, filtros);
  }

  @Get('no-leidas/count')
  contar(@Req() req: RequestConUsuario) {
    return this.logic.contarParaUsuario(req.user);
  }

  @Patch('leer-todas')
  leerTodas(@Body() dto: MarcarTodasLeidasDto, @Req() req: RequestConUsuario) {
    return this.logic.marcarTodasLeidas(req.user, dto);
  }

  @Patch(':id/leer')
  leer(@Param('id', ParseUUIDPipe) id: string, @Req() req: RequestConUsuario) {
    return this.logic.marcarLeida(id, req.user);
  }

  @Post()
  crear(@Body() dto: CrearNotificacionDto, @Req() req: RequestConUsuario) {
    return this.logic.crearManual(dto, req.user);
  }
}
