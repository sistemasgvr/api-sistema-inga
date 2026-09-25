import { Controller, Get, Param } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { GeneralListasLogic } from '../logic/general-listas.logic';

@ApiTags('General - Catalogos')
@Controller('general/listas')
export class GeneralListasController {
  constructor(private readonly listasLogic: GeneralListasLogic) {}

  @Get(':codigoLista/opciones')
  @ApiOperation({ summary: 'Obtener opciones de un catálogo por su código (ej. ALMACEN_TIPO, ESTACION_TIPO)' })
  obtenerOpcionesPorLista(@Param('codigoLista') codigoLista: string) {
    return this.listasLogic.obtenerOpcionesPorLista(codigoLista.toUpperCase());
  }
}