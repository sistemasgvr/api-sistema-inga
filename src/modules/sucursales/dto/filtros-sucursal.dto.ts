import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional } from 'class-validator';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export type SucursalEstadoFiltro = 'todos' | 'activos' | 'inactivos';

export class FiltroSucursalDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({
    enum: ['todos', 'activos', 'inactivos'],
    default: 'activos',
    description: 'Filtrar por estado de la sucursal',
  })
  @IsOptional()
  @IsIn(['todos', 'activos', 'inactivos'])
  estado?: SucursalEstadoFiltro = 'activos';
}