import {
  Body,
  Controller,
  Delete,
  Get,
  Post,
  Put,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { UsuarioAuditoria } from '../../../common/decorators/usuario-auditoria.decorator';
import { GuardarEmpresaDto } from '../dto/empresa.dto';
import { EmpresaLogic } from '../logic/empresa.logic';

@ApiTags('General - Empresa')
@Controller('general/empresa')
export class EmpresaController {
  constructor(private readonly empresaLogic: EmpresaLogic) {}

  @Get()
  @Permisos(PermisoBanderas.EMPRESA_VER)
  @ApiOperation({
    summary: 'Datos de la empresa (RUC, razón social, dirección y logo)',
  })
  obtener() {
    return this.empresaLogic.obtener();
  }

  @Put()
  @Permisos(PermisoBanderas.EMPRESA_EDITAR)
  @ApiOperation({ summary: 'Guardar los datos de la empresa' })
  guardar(
    @Body() dto: GuardarEmpresaDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
  ) {
    return this.empresaLogic.guardar(dto, idUsuarioAuditoria);
  }

  @Post('logo')
  @Permisos(PermisoBanderas.EMPRESA_EDITAR)
  @UseInterceptors(
    FileInterceptor('file', { limits: { fileSize: 5 * 1024 * 1024 } }),
  )
  @ApiOperation({
    summary:
      'Subir el logo de la empresa (también genera la versión para tickets)',
  })
  @ApiConsumes('multipart/form-data')
  subirLogo(
    @UploadedFile() file: Express.Multer.File,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
  ) {
    return this.empresaLogic.subirLogo(file, idUsuarioAuditoria);
  }

  @Delete('logo')
  @Permisos(PermisoBanderas.EMPRESA_EDITAR)
  @ApiOperation({ summary: 'Quitar el logo de la empresa' })
  eliminarLogo(@UsuarioAuditoria() idUsuarioAuditoria: number) {
    return this.empresaLogic.eliminarLogo(idUsuarioAuditoria);
  }
}
