import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';

export class CreateRecetaDto extends AuditoriaDto {
  @ApiPropertyOptional({ example: 'Receta Estándar Lomo Saltado' })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  nombre?: string;

  @ApiProperty({ description: 'Rendimiento en porciones', example: 1 })
  @IsNumber()
  @IsNotEmpty()
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
