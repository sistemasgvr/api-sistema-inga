import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsInt, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export type CategoriaEstadoFiltro = 'todos' | 'activos' | 'inactivos';

export class FiltroCategoriasProductoDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({
    enum: ['todos', 'activos', 'inactivos'],
    default: 'activos',
    description: 'Filtrar por estado de la categoría',
  })
  @IsOptional()
  estado?: CategoriaEstadoFiltro = 'activos';

  @ApiPropertyOptional({ description: 'Filtrar si es parte de la carta' })
  @IsOptional()
  es_carta?: boolean;
}

export class CreateCategoriaProductoDto extends AuditoriaDto {
  @ApiProperty({ example: 'Platos Principales', maxLength: 100 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  nombre!: string;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  descripcion?: string;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  es_carta?: boolean;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @IsInt()
  orden?: number;
}

export class UpdateCategoriaProductoDto extends AuditoriaDto {
  @ApiPropertyOptional({ maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  nombre?: string;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  descripcion?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  es_carta?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  orden?: number;
}
