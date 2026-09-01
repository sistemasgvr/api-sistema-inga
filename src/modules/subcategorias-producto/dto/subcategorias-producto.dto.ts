import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsInt, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export type SubCategoriaEstadoFiltro = 'todos' | 'activos' | 'inactivos';

export class FiltroSubCategoriasProductoDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({
    enum: ['todos', 'activos', 'inactivos'],
    default: 'activos',
    description: 'Filtrar por estado para los chips',
  })
  @IsOptional()
  estado?: SubCategoriaEstadoFiltro = 'activos';

  @ApiPropertyOptional({ description: 'Filtrar por ID de categoría padre' })
  @IsOptional()
  @IsInt()
  id_categoria?: number;
}

export class CreateSubCategoriaProductoDto extends AuditoriaDto {
  @ApiProperty({ description: 'ID de la categoría', example: 1 })
  @IsInt()
  @IsNotEmpty()
  id_categoria!: number;

  @ApiProperty({ description: 'Código único de la subcategoría', example: 'ENT-CRI', maxLength: 50 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  codigo!: string;

  @ApiProperty({ example: 'Entradas Criollas', maxLength: 100 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  nombre!: string;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @IsInt()
  orden?: number;
}

export class UpdateSubCategoriaProductoDto extends AuditoriaDto {
  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @IsInt()
  id_categoria?: number;

  @ApiPropertyOptional({ maxLength: 50 })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  codigo?: string;

  @ApiPropertyOptional({ maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  nombre?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  orden?: number;
}