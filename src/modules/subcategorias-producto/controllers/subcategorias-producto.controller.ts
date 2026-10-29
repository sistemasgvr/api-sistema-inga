import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiNotFoundResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import {
  Permisos,
  PermisosAlguno,
} from '../../../common/decorators/permisos.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import {
  CreateSubCategoriaProductoDto,
  FiltroSubCategoriasProductoDto,
  UpdateSubCategoriaProductoDto,
} from '../dto/subcategorias-producto.dto';
import { SubCategoriasProductoLogic } from '../logic/subcategorias-producto.logic';
import { UsuarioAuditoria } from '../../../common/decorators/usuario-auditoria.decorator';
import { EmpresaSesion } from '../../../common/decorators/sesion-empresa.decorator';

@ApiTags('Productos - Subcategorías')
@Controller('productos/subcategorias')
export class SubCategoriasProductoController {
  constructor(
    private readonly subCategoriasLogic: SubCategoriasProductoLogic,
  ) {}

  @Get()
  @PermisosAlguno(
    PermisoBanderas.CATEGORIAS_LISTAR,
    PermisoBanderas.SUBCATEGORIAS_LISTAR,
  )
  @ApiOperation({ summary: 'Listar subcategorías de producto' })
  listar(
    @Query() filtros: FiltroSubCategoriasProductoDto,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.subCategoriasLogic.listar(filtros, idEmpresa);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.SUBCATEGORIAS_VER)
  @ApiOperation({ summary: 'Obtener subcategoría por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(
    @Param('id', ParseIntPipe) id: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.subCategoriasLogic.obtenerPorId(id, idEmpresa);
  }

  @Post()
  @Permisos(PermisoBanderas.SUBCATEGORIAS_CREAR)
  @ApiOperation({ summary: 'Crear subcategoría de producto' })
  crear(
    @Body() dto: CreateSubCategoriaProductoDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.subCategoriasLogic.crear(
      { ...dto, idUsuarioAuditoria },
      idEmpresa,
    );
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.SUBCATEGORIAS_EDITAR)
  @ApiOperation({ summary: 'Actualizar subcategoría de producto' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateSubCategoriaProductoDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.subCategoriasLogic.actualizar(
      id,
      {
        ...dto,
        idUsuarioAuditoria,
      },
      idEmpresa,
    );
  }

  @Patch(':id/activar')
  @Permisos(PermisoBanderas.SUBCATEGORIAS_ACTIVAR)
  @ApiOperation({ summary: 'Activar subcategoría de producto' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  activar(
    @Param('id', ParseIntPipe) id: number,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.subCategoriasLogic.activar(id, idUsuarioAuditoria, idEmpresa);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.SUBCATEGORIAS_ELIMINAR)
  @ApiOperation({ summary: 'Desactivar subcategoría (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.subCategoriasLogic.eliminar(id, idUsuarioAuditoria, idEmpresa);
  }
}
