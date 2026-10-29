import {
  Body,
  Controller,
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
import { EmpresaSesion } from '../../../common/decorators/sesion-empresa.decorator';
import { UsuarioAuditoria } from '../../../common/decorators/usuario-auditoria.decorator';
import {
  GuardarConfiguracionSunatDto,
  SubirCertificadoDto,
} from '../dto/sunat.dto';
import { SunatConfiguracionLogic } from '../logic/sunat-configuracion.logic';

/** Facturación electrónica en la vista Empresa (Configuración → Empresa → SUNAT). */
@ApiTags('General - Empresa')
@Controller('general/empresa/sunat')
export class SunatConfiguracionController {
  constructor(private readonly logic: SunatConfiguracionLogic) {}

  @Get()
  @Permisos(PermisoBanderas.SUNAT_VER)
  @ApiOperation({
    summary:
      'Configuración SUNAT/APIsPERU: qué credenciales están cargadas (nunca las devuelve), ambiente y plazos de envío',
  })
  obtener(@EmpresaSesion() idEmpresa: number | null) {
    return this.logic.obtener(idEmpresa);
  }

  @Put()
  @Permisos(PermisoBanderas.SUNAT_EDITAR)
  @ApiOperation({
    summary:
      'Guardar token de APIsPERU, ambiente, usuario/clave SOL y días límite de envío (campos vacíos se conservan)',
  })
  guardar(
    @Body() dto: GuardarConfiguracionSunatDto,
    @UsuarioAuditoria() usuario: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.logic.guardar(dto, usuario, idEmpresa);
  }

  @Post('certificado')
  @Permisos(PermisoBanderas.SUNAT_EDITAR)
  @UseInterceptors(
    FileInterceptor('file', { limits: { fileSize: 1024 * 1024 } }),
  )
  @ApiConsumes('multipart/form-data')
  @ApiOperation({
    summary:
      'Subir el certificado digital (.pfx/.p12) con su contraseña: se valida, se guarda cifrado y se informa su vencimiento',
  })
  subirCertificado(
    @UploadedFile() file: Express.Multer.File,
    @Body() dto: SubirCertificadoDto,
    @UsuarioAuditoria() usuario: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.logic.subirCertificado(file, dto.clave, usuario, idEmpresa);
  }

  @Post('probar')
  @Permisos(PermisoBanderas.SUNAT_VER)
  @ApiOperation({
    summary:
      'Probar el token con APIsPERU (genera el XML de una boleta de prueba sin enviarla a SUNAT)',
  })
  probar(@EmpresaSesion() idEmpresa: number | null) {
    return this.logic.probar(idEmpresa);
  }
}
