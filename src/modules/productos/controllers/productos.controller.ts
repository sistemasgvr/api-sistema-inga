import {
  BadRequestException,
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
import { ApiConsumes, ApiNotFoundResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { CreateProductoDto, FiltroProductosDto, UpdateProductoDto } from '../dto/productos.dto';
import { ProductosLogic } from '../logic/productos.logic';
import { SupabaseStorageService } from '../../../integrations/supabase-storage/supabase-storage.service';

@ApiTags('Productos - Catálogo Principal')
@Controller('productos')
export class ProductosController {
  constructor(
    private readonly productosLogic: ProductosLogic,
    private readonly storageService: SupabaseStorageService,
  ) {}

  @Get()
  @Permisos(PermisoBanderas.PRODUCTOS_LISTAR)
  @ApiOperation({ summary: 'Listar productos con filtros y paginación' })
  listar(@Query() filtros: FiltroProductosDto) {
    return this.productosLogic.listar(filtros);
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
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.productosLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.PRODUCTOS_CREAR)
  @ApiOperation({ summary: 'Crear un nuevo producto' })
  crear(@Body() dto: CreateProductoDto) {
    return this.productosLogic.crear(dto);
  }

  @Post('upload-imagen')
  @Permisos(PermisoBanderas.PRODUCTOS_CREAR)
  @UseInterceptors(FileInterceptor('file'))
  @ApiOperation({ summary: 'Subir imagen de producto a Supabase Storage' })
  @ApiConsumes('multipart/form-data')
  async uploadImagen(@UploadedFile() file: Express.Multer.File) {
    if (!file) {
      throw new BadRequestException('Debes adjuntar un archivo de imagen');
    }

    const fileExt = file.originalname.split('.').pop();
    const path = `productos/prod_${Date.now()}_${Math.random().toString(36).substring(2, 7)}.${fileExt}`;

    const uploadResult = await this.storageService.upload(
      path,
      file.buffer,
      file.mimetype,
      true,
    );

    const publicUrl = this.storageService.getPublicUrl(uploadResult.path);

    return { url: publicUrl };
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.PRODUCTOS_EDITAR)
  @ApiOperation({ summary: 'Actualizar producto' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateProductoDto,
  ) {
    return this.productosLogic.actualizar(id, dto);
  }

  @Put(':id/disponibilidad')
  @Permisos(PermisoBanderas.PRODUCTOS_EDITAR)
  @ApiOperation({ summary: 'Cambiar disponibilidad de venta (toggle)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  toggleDisponibilidad(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.productosLogic.toggleDisponibilidad(id, dto.idUsuarioAuditoria);
  }

  @Patch(':id/activar')
  @Permisos(PermisoBanderas.PRODUCTOS_ACTIVAR)
  @ApiOperation({ summary: 'Activar producto inactivo' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  activar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.productosLogic.activar(id, dto.idUsuarioAuditoria);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.PRODUCTOS_ELIMINAR)
  @ApiOperation({ summary: 'Desactivar producto (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.productosLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}