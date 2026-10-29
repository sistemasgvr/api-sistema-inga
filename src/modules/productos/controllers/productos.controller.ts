import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Put,
  Query,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import 'multer';
import {
  ApiConsumes,
  ApiNotFoundResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import {
  CreateProductoDto,
  FiltroProductosDto,
  UpdateProductoDto,
} from '../dto/productos.dto';
import { ProductosLogic } from '../logic/productos.logic';
import { ProductoImagenLogic } from '../logic/producto-imagen.logic';
import { UsuarioAuditoria } from '../../../common/decorators/usuario-auditoria.decorator';
import { EmpresaSesion } from '../../../common/decorators/sesion-empresa.decorator';

@ApiTags('Productos - Catálogo Principal')
@Controller('productos')
export class ProductosController {
  constructor(
    private readonly productosLogic: ProductosLogic,
    private readonly productoImagenLogic: ProductoImagenLogic,
  ) {}

  @Get()
  @Permisos(PermisoBanderas.PRODUCTOS_LISTAR)
  @ApiOperation({ summary: 'Listar productos con filtros y paginación' })
  listar(
    @Query() filtros: FiltroProductosDto,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.productosLogic.listar(filtros, idEmpresa);
  }

  @Get('unidades')
  @Permisos(PermisoBanderas.PRODUCTOS_LISTAR)
  @ApiOperation({ summary: 'Listar unidades de medida y conversiones' })
  listarUnidades() {
    return this.productosLogic.listarUnidadesMedida();
  }

  @Get(':id')
  @Permisos(PermisoBanderas.PRODUCTOS_VER)
  @ApiOperation({ summary: 'Obtener producto por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(
    @Param('id', ParseIntPipe) id: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.productosLogic.obtenerPorId(id, idEmpresa);
  }

  @Post()
  @Permisos(PermisoBanderas.PRODUCTOS_CREAR)
  @ApiOperation({ summary: 'Crear un nuevo producto' })
  crear(
    @Body() dto: CreateProductoDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.productosLogic.crear({ ...dto, idUsuarioAuditoria }, idEmpresa);
  }

  @Post('upload-imagen')
  @Permisos(PermisoBanderas.PRODUCTOS_CREAR)
  @UseInterceptors(
    FileInterceptor('file', { limits: { fileSize: 5 * 1024 * 1024 } }),
  )
  @ApiOperation({ summary: 'Subir imagen de producto a Supabase Storage' })
  @ApiConsumes('multipart/form-data')
  async uploadImagen(@UploadedFile() file: Express.Multer.File) {
    return this.productoImagenLogic.subir(file);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.PRODUCTOS_EDITAR)
  @ApiOperation({ summary: 'Actualizar producto' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateProductoDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.productosLogic.actualizar(
      id,
      { ...dto, idUsuarioAuditoria },
      idEmpresa,
    );
  }

  @Put(':id/disponibilidad')
  @Permisos(PermisoBanderas.PRODUCTOS_EDITAR)
  @ApiOperation({ summary: 'Cambiar disponibilidad de venta (toggle)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  toggleDisponibilidad(
    @Param('id', ParseIntPipe) id: number,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.productosLogic.toggleDisponibilidad(
      id,
      idUsuarioAuditoria,
      idEmpresa,
    );
  }

  @Patch(':id/activar')
  @Permisos(PermisoBanderas.PRODUCTOS_ACTIVAR)
  @ApiOperation({ summary: 'Activar producto inactivo' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  activar(
    @Param('id', ParseIntPipe) id: number,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.productosLogic.activar(id, idUsuarioAuditoria, idEmpresa);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.PRODUCTOS_ELIMINAR)
  @ApiOperation({ summary: 'Desactivar producto (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.productosLogic.eliminar(id, idUsuarioAuditoria, idEmpresa);
  }
}
