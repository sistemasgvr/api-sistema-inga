import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class FiltroPermisoDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({
    example: 'AUTH',
    description: 'Filtrar permisos por código de módulo (AUTH, VENTAS, CAJA, etc.)',
  })
  @IsOptional()
  @IsString()
  modulo?: string;
}