import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export type ConvenioEstadoFiltro = 'todos' | 'activos' | 'inactivos';

export class FiltroConveniosDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({
    enum: ['todos', 'activos', 'inactivos'],
    default: 'activos',
    description: 'Filtrar por estado del convenio',
  })
  @IsOptional()
  estado?: ConvenioEstadoFiltro = 'activos';
}

export class CreateConvenioDto extends AuditoriaDto {
  @ApiProperty({ example: 'GVR', maxLength: 50, description: 'Se guarda en mayúsculas' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  codigo!: string;

  @ApiProperty({ example: 'GVR', maxLength: 150 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(150)
  nombre!: string;

  @ApiProperty({ example: 2, description: 'ID de gen_condicion_pago' })
  @IsInt()
  @IsNotEmpty()
  id_condicion_pago!: number;

  @ApiPropertyOptional({
    example: 1500,
    default: 0,
    description: 'Tope de deuda. 0 = sin tope definido',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  limite_credito?: number;

  @ApiPropertyOptional({
    default: true,
    description: 'Si el corte de cuenta es cada quincena',
  })
  @IsOptional()
  @IsBoolean()
  corte_quincenal?: boolean;
}

export class UpdateConvenioDto extends AuditoriaDto {
  @ApiPropertyOptional({ maxLength: 50 })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  codigo?: string;

  @ApiPropertyOptional({ maxLength: 150 })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  nombre?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  id_condicion_pago?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  limite_credito?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  corte_quincenal?: boolean;
}
