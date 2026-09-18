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
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import {
  BuscarPersonasDto,
  CreatePersonaDto,
  FiltroPersonasDto,
  UpdatePersonaDto,
} from '../dto/personas.dto';
import { PersonasLogic } from '../logic/personas.logic';

@ApiTags('Personas - Clientes y proveedores')
@Controller('personas')
export class PersonasController {
  constructor(private readonly personasLogic: PersonasLogic) {}

  @Get()
  @Permisos(PermisoBanderas.PERSONAS_LISTAR)
  @ApiOperation({ summary: 'Listar personas (clientes y proveedores)' })
  listar(@Query() filtros: FiltroPersonasDto) {
    return this.personasLogic.listar(filtros);
  }

  // Igual que en convenios: '/personas/buscar' va antes que '/personas/:id'
  // porque Nest resuelve las rutas en orden de declaración. Si estuviera
  // después, ':id' capturaría la palabra "buscar" y el ParseIntPipe fallaría.
  @Get('buscar')
  @Permisos(PermisoBanderas.PERSONAS_LISTAR)
  @ApiOperation({
    summary:
      'Buscador rápido para autocompletar (lo usan compras y cobro a crédito)',
  })
  buscar(@Query() dto: BuscarPersonasDto) {
    return this.personasLogic.buscar(dto);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.PERSONAS_VER)
  @ApiOperation({ summary: 'Obtener persona por ID (incluye su saldo de crédito)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.personasLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.PERSONAS_CREAR)
  @ApiOperation({ summary: 'Crear persona' })
  crear(@Body() dto: CreatePersonaDto) {
    return this.personasLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.PERSONAS_EDITAR)
  @ApiOperation({ summary: 'Actualizar persona' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdatePersonaDto,
  ) {
    return this.personasLogic.actualizar(id, dto);
  }

  @Patch(':id/activar')
  @Permisos(PermisoBanderas.PERSONAS_ACTIVAR)
  @ApiOperation({ summary: 'Reactivar persona' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  activar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.personasLogic.activar(id, dto.idUsuarioAuditoria);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.PERSONAS_ELIMINAR)
  @ApiOperation({
    summary: 'Dar de baja persona (baja lógica; falla si tiene deuda pendiente)',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.personasLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
