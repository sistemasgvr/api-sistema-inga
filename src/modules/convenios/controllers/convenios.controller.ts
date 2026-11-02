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
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import {
  CreateConvenioDto,
  FiltroConveniosDto,
  UpdateConvenioDto,
} from '../dto/convenios.dto';
import { ConveniosLogic } from '../logic/convenios.logic';
import { UsuarioAuditoria } from '../../../common/decorators/usuario-auditoria.decorator';
import { EmpresaSesion } from '../../../common/decorators/sesion-empresa.decorator';

@ApiTags('Personas - Convenios de crédito')
@Controller('convenios')
export class ConveniosController {
  constructor(private readonly conveniosLogic: ConveniosLogic) {}

  @Get()
  @Permisos(PermisoBanderas.CONVENIOS_LISTAR)
  @ApiOperation({ summary: 'Listar convenios de crédito' })
  listar(
    @Query() filtros: FiltroConveniosDto,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.conveniosLogic.listar(filtros, idEmpresa);
  }

  // OJO con el orden: esta ruta va ANTES de @Get(':id') a propósito.
  // Nest registra las rutas en el orden en que las declaro, así que si
  // ':id' estuviera primero se comería '/convenios/condiciones-pago',
  // intentaría convertir "condiciones-pago" a número y devolvería un 400.
  @Get('condiciones-pago')
  @Permisos(PermisoBanderas.CONVENIOS_LISTAR)
  @ApiOperation({
    summary:
      'Listar condiciones de pago disponibles (para el selector del formulario)',
  })
  listarCondicionesPago() {
    return this.conveniosLogic.listarCondicionesPago();
  }

  @Get(':id')
  @Permisos(PermisoBanderas.CONVENIOS_VER)
  @ApiOperation({ summary: 'Obtener convenio por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(
    @Param('id', ParseIntPipe) id: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.conveniosLogic.obtenerPorId(id, idEmpresa);
  }

  @Post()
  @Permisos(PermisoBanderas.CONVENIOS_CREAR)
  @ApiOperation({ summary: 'Crear convenio de crédito' })
  crear(
    @Body() dto: CreateConvenioDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.conveniosLogic.crear({ ...dto, idUsuarioAuditoria }, idEmpresa);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.CONVENIOS_EDITAR)
  @ApiOperation({ summary: 'Actualizar convenio' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateConvenioDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.conveniosLogic.actualizar(
      id,
      { ...dto, idUsuarioAuditoria },
      idEmpresa,
    );
  }

  @Patch(':id/activar')
  @Permisos(PermisoBanderas.CONVENIOS_ACTIVAR)
  @ApiOperation({ summary: 'Reactivar convenio' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  activar(
    @Param('id', ParseIntPipe) id: number,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.conveniosLogic.activar(id, idUsuarioAuditoria, idEmpresa);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.CONVENIOS_ELIMINAR)
  @ApiOperation({
    summary:
      'Dar de baja convenio (baja lógica; falla si tiene clientes asignados)',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.conveniosLogic.eliminar(id, idUsuarioAuditoria, idEmpresa);
  }
}
