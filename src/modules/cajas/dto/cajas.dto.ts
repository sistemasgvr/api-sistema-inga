import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export type CajaEstadoFiltro = 'todos' | 'activos' | 'inactivos';

export class FiltroCajasDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({
    enum: ['todos', 'activos', 'inactivos'],
    default: 'activos',
  })
  @IsOptional()
  estado?: CajaEstadoFiltro = 'activos';

  @ApiPropertyOptional({ description: 'Filtrar por sucursal' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  id_sucursal?: number;
}

export class CreateCajaDto extends AuditoriaDto {
  @ApiProperty({ example: 1 })
  @IsInt()
  @IsNotEmpty()
  id_sucursal!: number;

  @ApiProperty({ example: 'CAJA-01', maxLength: 50, description: 'Único por sucursal' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  codigo!: string;

  @ApiProperty({ example: 'Caja principal', maxLength: 100 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  nombre!: string;
}

export class UpdateCajaDto extends AuditoriaDto {
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
}
