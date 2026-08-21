import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional } from 'class-validator';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export type RolEstadoFiltro = 'todos' | 'activos' | 'inactivos';

export class FiltroRolDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({
    enum: ['todos', 'activos', 'inactivos'],
    default: 'activos',
    description: 'Filtrar por estado del rol',
  })
  @IsOptional()
  @IsIn(['todos', 'activos', 'inactivos'])
  estado?: RolEstadoFiltro = 'activos';
}