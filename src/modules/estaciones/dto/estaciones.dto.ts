import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsInt, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';
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
  @IsInt()
  id_sucursal?: number;
}

export class CreateEstacionDto extends AuditoriaDto {
  @ApiProperty({ description: 'ID de la sucursal', example: 1 })
  @IsInt()
  @IsNotEmpty()
  id_sucursal!: number;

  @ApiProperty({ example: 'EST-COC', maxLength: 50 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  codigo!: string;

  @ApiProperty({ example: 'Cocina Principal', maxLength: 100 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  nombre!: string;

  @ApiProperty({ description: 'Tipo de estación (según catálogo ESTACION_TIPO)', example: 1 })
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
  impresora_ip?: string;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  usa_kds?: boolean;
}

export class UpdateEstacionDto extends AuditoriaDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  id_sucursal?: number;

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
  impresora_ip?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  usa_kds?: boolean;
}