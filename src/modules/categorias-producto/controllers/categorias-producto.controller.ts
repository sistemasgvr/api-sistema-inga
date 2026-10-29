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
  CreateCategoriaProductoDto,
  FiltroCategoriasProductoDto,
  UpdateCategoriaProductoDto,
} from '../dto/categorias-producto.dto';
import { CategoriasProductoLogic } from '../logic/categorias-producto.logic';
import { UsuarioAuditoria } from '../../../common/decorators/usuario-auditoria.decorator';
import { EmpresaSesion } from '../../../common/decorators/sesion-empresa.decorator';

@ApiTags('Productos - Categorías')
@Controller('productos/categorias')
export class CategoriasProductoController {
  constructor(
    private readonly categoriasProductoLogic: CategoriasProductoLogic,
  ) {}

  @Get()
  @PermisosAlguno(
    PermisoBanderas.CATEGORIAS_LISTAR,
    PermisoBanderas.SUBCATEGORIAS_LISTAR,
  )
  @ApiOperation({ summary: 'Listar categorías de producto' })
  listar(
    @Query() filtros: FiltroCategoriasProductoDto,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.categoriasProductoLogic.listar(filtros, idEmpresa);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.CATEGORIAS_VER)
  @ApiOperation({ summary: 'Obtener categoría por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(
    @Param('id', ParseIntPipe) id: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.categoriasProductoLogic.obtenerPorId(id, idEmpresa);
  }

  @Post()
  @Permisos(PermisoBanderas.CATEGORIAS_CREAR)
  @ApiOperation({ summary: 'Crear categoría de producto' })
  crear(
    @Body() dto: CreateCategoriaProductoDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.categoriasProductoLogic.crear(
      { ...dto, idUsuarioAuditoria },
      idEmpresa,
    );
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.CATEGORIAS_EDITAR)
  @ApiOperation({ summary: 'Actualizar categoría de producto' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateCategoriaProductoDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.categoriasProductoLogic.actualizar(
      id,
      {
        ...dto,
        idUsuarioAuditoria,
      },
      idEmpresa,
    );
  }

  @Patch(':id/activar')
  @Permisos(PermisoBanderas.CATEGORIAS_ACTIVAR)
  @ApiOperation({ summary: 'Activar categoría de producto' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  activar(
    @Param('id', ParseIntPipe) id: number,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.categoriasProductoLogic.activar(
      id,
      idUsuarioAuditoria,
      idEmpresa,
    );
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.CATEGORIAS_ELIMINAR)
  @ApiOperation({ summary: 'Desactivar categoría (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.categoriasProductoLogic.eliminar(
      id,
      idUsuarioAuditoria,
      idEmpresa,
    );
  }
}
