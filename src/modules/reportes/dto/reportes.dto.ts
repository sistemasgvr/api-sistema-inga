import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsDateString, IsInt, IsOptional, Min } from 'class-validator';

/** Filtro común del dashboard y de todos los reportes. */
export class FiltroReporteDto {
  @ApiProperty({ example: '2026-10-01', description: 'Desde (día de Lima)' })
  @IsDateString()
  fecha_desde!: string;

  @ApiProperty({ example: '2026-10-31', description: 'Hasta (día de Lima)' })
  @IsDateString()
  fecha_hasta!: string;

  @ApiPropertyOptional({ description: 'Sucursal; sin valor = todas' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  id_sucursal?: number;
}
