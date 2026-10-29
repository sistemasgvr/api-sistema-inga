import { Body, Controller, Get, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { UsuarioAuditoria } from '../../../common/decorators/usuario-auditoria.decorator';
import { EmpresaSesion } from '../../../common/decorators/sesion-empresa.decorator';
import { CreateTipoProductoDto } from '../dto/tipos-producto.dto';
import { TiposProductoLogic } from '../logic/tipos-producto.logic';

@ApiTags('Tipos de producto')
@Controller('tipos-producto')
export class TiposProductoController {
  constructor(private readonly logic: TiposProductoLogic) {}
  @Get()
  listar(@EmpresaSesion() idEmpresa: number | null) {
    return this.logic.listar(idEmpresa);
  }

  @Post()
  @Permisos(PermisoBanderas.PRODUCTOS_CREAR)
  crear(
    @Body() dto: CreateTipoProductoDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.logic.crear({ ...dto, idUsuarioAuditoria }, idEmpresa);
  }
}
