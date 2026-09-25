import { Controller, Get, Param } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiNotFoundResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import { ListaCodigoParamDto, ListaIdParamDto } from '../dto/listas.dto';
import { ListasLogic } from '../logic/listas.logic';

// Catálogos comunes a los formularios: accesibles a cualquier usuario con JWT válido.
// No requieren permisos de administración del módulo que los consume.
@ApiTags('General - Listas')
@ApiBearerAuth()
@Controller('general/listas')
export class ListasController {
  constructor(private readonly logic: ListasLogic) {}

  @Get()
  @ApiOperation({ summary: 'Listar catálogos activos (ID, código y nombre)' })
  listar() {
    return this.logic.listar();
  }

  @Get('codigo/:codigo/opciones')
  @ApiOperation({
    summary: 'Obtener una lista por código y sus opciones activas ordenadas',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  porCodigo(@Param() params: ListaCodigoParamDto) {
    return this.logic.obtenerOpciones(null, params.codigo);
  }

  @Get(':id/opciones')
  @ApiOperation({
    summary: 'Obtener una lista por ID y sus opciones activas ordenadas',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  porId(@Param() params: ListaIdParamDto) {
    return this.logic.obtenerOpciones(params.id, null);
  }
}
