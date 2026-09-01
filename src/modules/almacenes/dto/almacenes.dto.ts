import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsInt, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export type AlmacenEstadoFiltro = 'todos' | 'activos' | 'inactivos';

export class FiltroAlmacenesDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({
    enum: ['todos', 'activos', 'inactivos'],
    default: 'activos',
    description: 'Filtrar por estado del almacén',
  })
  @IsOptional()
  estado?: AlmacenEstadoFiltro = 'activos';

  @ApiPropertyOptional({ description: 'Filtrar por ID de sucursal' })
  @IsOptional()
  @IsInt()
  id_sucursal?: number;
}

export class CreateAlmacenDto extends AuditoriaDto {
  @ApiProperty({ description: 'ID de la sucursal', example: 1 })
  @IsInt()
  @IsNotEmpty()
  id_sucursal!: number;

  @ApiProperty({ example: 'ALM-01', maxLength: 50 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  codigo!: string;

  @ApiProperty({ example: 'Almacén Principal', maxLength: 100 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  nombre!: string;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  descripcion?: string;

  @ApiProperty({ description: 'Tipo de almacén (según catálogo ALMACEN_TIPO)', example: 1 })
  @IsInt()
  @IsNotEmpty()
  tipo_almacen!: number;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  es_principal?: boolean;
}

export class UpdateAlmacenDto extends AuditoriaDto {
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

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  descripcion?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  tipo_almacen?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  es_principal?: boolean;
}