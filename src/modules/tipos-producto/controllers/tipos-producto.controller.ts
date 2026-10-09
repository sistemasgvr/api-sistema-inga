import { Body, Controller, Get, Post, Req } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { CreateTipoProductoDto } from '../dto/tipos-producto.dto';
import { TiposProductoLogic } from '../logic/tipos-producto.logic';

@ApiTags('Tipos de producto')
@Controller('tipos-producto')
export class TiposProductoController {
  constructor(private readonly logic: TiposProductoLogic) {}
  @Get()
  listar() {
    return this.logic.listar();
  }

  @Post()
  @Permisos(PermisoBanderas.PRODUCTOS_CREAR)
  crear(
    @Body() dto: CreateTipoProductoDto,
    @Req() req: { user: { id: number } },
  ) {
    return this.logic.crear({ ...dto, idUsuarioAuditoria: req.user.id });
  }
}
