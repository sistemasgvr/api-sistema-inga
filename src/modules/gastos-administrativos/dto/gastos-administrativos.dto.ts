import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsDateString,
  IsIn,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export type GastoEstadoFiltro = 'todos' | 'activos' | 'inactivos';

/** Fijo = se repite cada mes. Variable = puntual. */
export const TIPO_GASTO = { FIJO: 1, VARIABLE: 2 } as const;

/** Catálogo MEDIO_PAGO. Sin crédito: un gasto administrativo se paga al momento. */
export const MEDIO_PAGO_GASTO = {
  EFECTIVO: 1,
  YAPE: 2,
  TARJETA: 3,
} as const;

/* ------------------------------- Categorías ------------------------------- */

export class FiltroCategoriasGastoDto {
  @ApiPropertyOptional({ enum: [1, 2], description: '1 = fijo, 2 = variable' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @IsIn([1, 2])
  tipo_gasto?: number;

  @ApiPropertyOptional({
    enum: ['todos', 'activos', 'inactivos'],
    default: 'activos',
  })
  @IsOptional()
  estado?: GastoEstadoFiltro = 'activos';
}

export class CreateCategoriaGastoDto extends AuditoriaDto {
  @ApiProperty({ example: 'ALQUILER', maxLength: 50 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  codigo!: string;

  @ApiProperty({ example: 'Alquiler del local', maxLength: 100 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  nombre!: string;

  @ApiPropertyOptional({
    enum: [1, 2],
    default: 1,
    description: 'Se ignora si se indica categoría padre: hereda el tipo del padre.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @IsIn([1, 2])
  tipo_gasto?: number;

  @ApiPropertyOptional({
    description: 'Para crear una subcategoría. Solo se admite un nivel de anidación.',
  })
  @IsOptional()
  @IsInt()
  id_categoria_padre?: number;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  orden?: number;
}

export class UpdateCategoriaGastoDto extends AuditoriaDto {
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

  @ApiPropertyOptional({ enum: [1, 2] })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @IsIn([1, 2])
  tipo_gasto?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  orden?: number;
}

/* --------------------------------- Gastos --------------------------------- */

export class FiltroGastosDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({
    description: 'Incluye los gastos de sus subcategorías',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  id_categoria?: number;

  @ApiPropertyOptional({ enum: [1, 2] })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @IsIn([1, 2])
  tipo_gasto?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  anio?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(12)
  mes?: number;

  @ApiPropertyOptional({ enum: [1, 2, 3] })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @IsIn([1, 2, 3])
  medio_pago?: number;

  @ApiPropertyOptional({ example: '2026-09-01' })
  @IsOptional()
  @IsDateString()
  fecha_desde?: string;

  @ApiPropertyOptional({ example: '2026-09-30' })
  @IsOptional()
  @IsDateString()
  fecha_hasta?: string;
}

export class CreateGastoDto extends AuditoriaDto {
  @ApiProperty({ example: 2 })
  @IsInt()
  @IsNotEmpty()
  id_categoria!: number;

  @ApiProperty({ example: 'Recibo de luz - septiembre', maxLength: 255 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  concepto!: string;

  @ApiProperty({ example: 480.5 })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01, { message: 'El monto debe ser mayor a cero' })
  monto!: number;

  @ApiPropertyOptional({
    example: '2026-09-05',
    description: 'Por defecto, hoy. De ella se derivan el año y el mes del reporte.',
  })
  @IsOptional()
  @IsDateString()
  fecha_gasto?: string;

  @ApiPropertyOptional({
    enum: [1, 2, 3],
    default: 1,
    description: '1 efectivo (exige turno abierto), 2 yape, 3 tarjeta/transferencia',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @IsIn([1, 2, 3])
  medio_pago?: number;

  @ApiPropertyOptional({
    description: 'Turno de caja. Obligatorio cuando medio_pago = 1 (efectivo).',
  })
  @IsOptional()
  @IsInt()
  id_turno?: number;

  @ApiPropertyOptional({
    description: 'Proveedor del servicio. Opcional, útil para agrupar recibos.',
  })
  @IsOptional()
  @IsInt()
  id_persona?: number;

  @ApiPropertyOptional({ maxLength: 50 })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  num_comprobante?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  id_sucursal?: number;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  observacion?: string;
}

export class UpdateGastoDto extends AuditoriaDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  id_categoria?: number;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  concepto?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  monto?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fecha_gasto?: string;

  @ApiPropertyOptional({ enum: [1, 2, 3] })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @IsIn([1, 2, 3])
  medio_pago?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  id_persona?: number;

  @ApiPropertyOptional({ maxLength: 50 })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  num_comprobante?: string;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  observacion?: string;
}

export class AnularGastoDto extends AuditoriaDto {
  @ApiPropertyOptional({
    maxLength: 255,
    description: 'Queda guardado en la observación del gasto anulado.',
  })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  motivo?: string;
}

export class FiltroReporteMensualDto {
  @ApiPropertyOptional({ description: 'Por defecto, el año actual' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  anio?: number;

  @ApiPropertyOptional({ description: 'Por defecto, el mes actual' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(12)
  mes?: number;
}
