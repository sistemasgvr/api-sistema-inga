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
  BuscarPersonasDto,
  ConsultaDocumentoDto,
  CreatePersonaDto,
  FiltroPersonasDto,
  UpdatePersonaDto,
} from '../dto/personas.dto';
import { PersonasLogic } from '../logic/personas.logic';
import { ConsultaDocumentoLogic } from '../logic/consulta-documento.logic';
import { UsuarioAuditoria } from '../../../common/decorators/usuario-auditoria.decorator';
import { EmpresaSesion } from '../../../common/decorators/sesion-empresa.decorator';

@ApiTags('Personas - Clientes y proveedores')
@Controller('personas')
export class PersonasController {
  constructor(
    private readonly personasLogic: PersonasLogic,
    private readonly consultaDocumento: ConsultaDocumentoLogic,
  ) {}

  @Get()
  @Permisos(PermisoBanderas.PERSONAS_LISTAR)
  @ApiOperation({ summary: 'Listar personas (clientes y proveedores)' })
  listar(
    @Query() filtros: FiltroPersonasDto,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.personasLogic.listar(filtros, idEmpresa);
  }

  // Igual que en convenios: '/personas/buscar' va antes que '/personas/:id'
  // porque Nest resuelve las rutas en orden de declaración. Si estuviera
  // después, ':id' capturaría la palabra "buscar" y el ParseIntPipe fallaría.
  // También antes de ':id'. La usan el cobro, el alta de clientes y la vista Empresa.
  @Get('consulta/:numero')
  @PermisosAlguno(
    PermisoBanderas.PERSONAS_LISTAR,
    PermisoBanderas.PERSONAS_CREAR,
    PermisoBanderas.EMPRESA_EDITAR,
  )
  @ApiOperation({
    summary:
      'Consulta un DNI o RUC: el cliente ya registrado en la empresa o, si no existe, RENIEC / SUNAT (APIsPERU). No registra nada.',
  })
  consultar(
    @Param() params: ConsultaDocumentoDto,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.consultaDocumento.consultar(params.numero, idEmpresa);
  }

  @Get('buscar')
  @Permisos(PermisoBanderas.PERSONAS_LISTAR)
  @ApiOperation({
    summary:
      'Buscador rápido para autocompletar (lo usan compras y cobro a crédito)',
  })
  buscar(
    @Query() dto: BuscarPersonasDto,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.personasLogic.buscar(dto, idEmpresa);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.PERSONAS_VER)
  @ApiOperation({
    summary: 'Obtener persona por ID (incluye su saldo de crédito)',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(
    @Param('id', ParseIntPipe) id: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.personasLogic.obtenerPorId(id, idEmpresa);
  }

  @Post()
  @Permisos(PermisoBanderas.PERSONAS_CREAR)
  @ApiOperation({ summary: 'Crear persona' })
  crear(
    @Body() dto: CreatePersonaDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.personasLogic.crear({ ...dto, idUsuarioAuditoria }, idEmpresa);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.PERSONAS_EDITAR)
  @ApiOperation({ summary: 'Actualizar persona' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdatePersonaDto,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.personasLogic.actualizar(
      id,
      { ...dto, idUsuarioAuditoria },
      idEmpresa,
    );
  }

  @Patch(':id/activar')
  @Permisos(PermisoBanderas.PERSONAS_ACTIVAR)
  @ApiOperation({ summary: 'Reactivar persona' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  activar(
    @Param('id', ParseIntPipe) id: number,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.personasLogic.activar(id, idUsuarioAuditoria, idEmpresa);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.PERSONAS_ELIMINAR)
  @ApiOperation({
    summary:
      'Dar de baja persona (baja lógica; falla si tiene deuda pendiente)',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @UsuarioAuditoria() idUsuarioAuditoria: number,
    @EmpresaSesion() idEmpresa: number | null,
  ) {
    return this.personasLogic.eliminar(id, idUsuarioAuditoria, idEmpresa);
  }
}
