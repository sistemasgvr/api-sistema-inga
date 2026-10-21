import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  Max,
} from 'class-validator';
import { Type } from 'class-transformer';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { CantidadMaxima } from '../../../common/decorators/limites.decorator';

/**
 * Filtros del selector de insumos del recetario.
 *
 * El recetario es multi-nivel: una receta admite insumos crudos y también
 * platos que tienen su propia receta, así que el selector se apoya en los
 * mismos filtros que el catálogo de productos en vez de fijar un tipo.
 */
export class FiltroInsumosRecetaDto {
  @ApiPropertyOptional({ description: 'Texto a buscar en nombre' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  busqueda?: string;

  @ApiPropertyOptional({ description: 'ID del tipo de producto' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  id_tipo_producto?: number;

  @ApiPropertyOptional({ description: 'ID de la categoría' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  id_categoria?: number;

  @ApiPropertyOptional({ description: 'ID de la subcategoría' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  id_subcategoria?: number;
}

export class CreateRecetaDto extends AuditoriaDto {
  @ApiPropertyOptional({ example: 'Receta Estándar Lomo Saltado' })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  nombre?: string;

  @ApiProperty({ description: 'Rendimiento en porciones', example: 1 })
  @IsNumber()
  @IsNotEmpty()
  @CantidadMaxima()
  rendimiento_porciones!: number;

  @ApiPropertyOptional({ description: 'Observaciones de preparación' })
  @IsOptional()
  @IsString()
  observacion?: string;
}

export class GuardarRecetaInsumoDto extends AuditoriaDto {
  @ApiProperty({
    description: 'ID del producto insumo (debe ser procesado u otro permitido)',
    example: 5,
  })
  @IsInt()
  @IsNotEmpty()
  id_producto_insumo!: number;

  @ApiProperty({ description: 'Cantidad necesaria', example: 150.0 })
  @IsNumber()
  @IsNotEmpty()
  @Min(0.0001)
  @CantidadMaxima()
  cantidad!: number;

  @ApiProperty({
    description: 'ID de la unidad de medida del insumo',
    example: 3,
  })
  @IsInt()
  @IsNotEmpty()
  id_unidad_medida!: number;

  @ApiPropertyOptional({
    description: 'Porcentaje de merma estimado',
    default: 0,
  })
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100)
  porcentaje_merma?: number;

  @ApiPropertyOptional({
    description: 'Si el insumo es opcional',
    default: false,
  })
  @IsOptional()
  @IsBoolean()
  es_opcional?: boolean;

  @ApiPropertyOptional({
    description: 'Grupo de sustitución para alternativas (ej: pescados)',
  })
  @IsOptional()
  @IsInt()
  grupo_sustitucion?: number;

  @ApiPropertyOptional({ description: 'Orden de visualización', default: 0 })
  @IsOptional()
  @IsInt()
  orden?: number;
}
