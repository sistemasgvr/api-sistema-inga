import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsIn,
  IsIP,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  ValidateIf,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export type EstacionEstadoFiltro = 'todos' | 'activos' | 'inactivos';

export class FiltroEstacionesDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({
    enum: ['todos', 'activos', 'inactivos'],
    default: 'activos',
    description: 'Filtrar por estado de la estación',
  })
  @IsOptional()
  estado?: EstacionEstadoFiltro = 'activos';

  @ApiPropertyOptional({ description: 'Filtrar por ID de sucursal' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  id_sucursal?: number;
}

export class CreateEstacionDto extends AuditoriaDto {
  @ApiProperty({ description: 'ID de la sucursal', example: 1 })
  @IsInt()
  @IsNotEmpty()
  id_sucursal!: number;

  @ApiProperty({ example: 'Cocina Principal', maxLength: 100 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  nombre!: string;

  @ApiProperty({
    description: 'Tipo de estación (según catálogo ESTACION_TIPO)',
    example: 1,
  })
  @IsInt()
  @IsNotEmpty()
  tipo_estacion!: number;

  @ApiPropertyOptional({ maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  impresora_nombre?: string;

  @ApiPropertyOptional({ maxLength: 45 })
  @IsOptional()
  @IsString()
  @MaxLength(45)
  @ValidateIf(
    (_object, value) => typeof value === 'string' && value.trim() !== '',
  )
  @IsIP('4', { message: 'La IP de la impresora no es válida' })
  impresora_ip?: string;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  usa_kds?: boolean;

  @ApiPropertyOptional({
    enum: [58, 80],
    default: 80,
    description: 'Ancho del rollo de la impresora (mm)',
  })
  @IsOptional()
  @IsIn([58, 80], { message: 'El ancho de papel debe ser 58 u 80 mm' })
  ancho_papel?: number;
}

export class UpdateEstacionDto extends AuditoriaDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  id_sucursal?: number;

  @ApiPropertyOptional({ maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  nombre?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  tipo_estacion?: number;

  @ApiPropertyOptional({ maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  impresora_nombre?: string;

  @ApiPropertyOptional({ maxLength: 45 })
  @IsOptional()
  @IsString()
  @MaxLength(45)
  @ValidateIf(
    (_object, value) => typeof value === 'string' && value.trim() !== '',
  )
  @IsIP('4', { message: 'La IP de la impresora no es válida' })
  impresora_ip?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  usa_kds?: boolean;

  @ApiPropertyOptional({
    enum: [58, 80],
    default: 80,
    description: 'Ancho del rollo de la impresora (mm)',
  })
  @IsOptional()
  @IsIn([58, 80], { message: 'El ancho de papel debe ser 58 u 80 mm' })
  ancho_papel?: number;
}
