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

export type TrabajadorEstadoFiltro = 'todos' | 'activos' | 'inactivos';

/**
 * Medios de pago admitidos en planilla (catálogo MEDIO_PAGO).
 * No incluyo el 4 (crédito): a un trabajador no se le paga a crédito.
 */
export const MEDIO_PAGO_PLANILLA = {
  EFECTIVO: 1,
  YAPE: 2,
  TARJETA: 3,
} as const;

/* ------------------------------ Trabajadores ------------------------------ */

export class FiltroTrabajadoresDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({
    enum: ['todos', 'activos', 'inactivos'],
    default: 'activos',
  })
  @IsOptional()
  estado?: TrabajadorEstadoFiltro = 'activos';

  @ApiPropertyOptional({
    description: 'Año del período a consultar. Por defecto, el año actual.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  anio?: number;

  @ApiPropertyOptional({
    description: 'Mes del período a consultar. Por defecto, el mes actual.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(12)
  mes?: number;

  @ApiPropertyOptional({
    enum: [1, 2],
    description: 'Acota el acumulado a una quincena concreta',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @IsIn([1, 2])
  quincena?: number;
}

export class CreateTrabajadorDto extends AuditoriaDto {
  @ApiProperty({ example: 'María', maxLength: 100 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  nombres!: string;

  @ApiProperty({ example: 'Quispe Rojas', maxLength: 100 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  apellidos!: string;

  @ApiPropertyOptional({
    example: '45612345',
    maxLength: 20,
    description: 'Opcional. Único cuando se informa.',
  })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  num_documento?: string;

  @ApiPropertyOptional({ example: 'Cocinera', maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  puesto?: string;

  @ApiPropertyOptional({
    example: 750,
    default: 0,
    description: 'Monto habitual de la quincena. Solo sugiere el importe al pagar.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  sueldo_referencial?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  id_sucursal?: number;
}

export class UpdateTrabajadorDto extends AuditoriaDto {
  @ApiPropertyOptional({ maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  nombres?: string;

  @ApiPropertyOptional({ maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  apellidos?: string;

  @ApiPropertyOptional({ maxLength: 20 })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  num_documento?: string;

  @ApiPropertyOptional({ maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  puesto?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  sueldo_referencial?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  id_sucursal?: number;
}

/* --------------------------------- Pagos ---------------------------------- */

export class FiltroPagosDto extends FiltroPaginacionDto {
  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  id_trabajador?: number;

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

  @ApiPropertyOptional({ enum: [1, 2] })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @IsIn([1, 2])
  quincena?: number;

  @ApiPropertyOptional({ enum: [1, 2, 3], description: '1 efectivo, 2 yape, 3 tarjeta' })
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

export class CreatePagoDto extends AuditoriaDto {
  @ApiProperty({ example: 3 })
  @IsInt()
  @IsNotEmpty()
  id_trabajador!: number;

  @ApiProperty({ example: 750.0 })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01, { message: 'El monto debe ser mayor a cero' })
  monto!: number;

  @ApiPropertyOptional({
    example: '2026-09-17',
    description: 'Por defecto, hoy. De ella se deduce la quincena.',
  })
  @IsOptional()
  @IsDateString()
  fecha_pago?: string;

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
    description:
      'Fuerza el período. Solo para cargar pagos atrasados o corregir historial; ' +
      'normalmente se deduce de fecha_pago.',
  })
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

  @ApiPropertyOptional({ enum: [1, 2] })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @IsIn([1, 2])
  quincena?: number;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  observacion?: string;
}

export class AnularPagoDto extends AuditoriaDto {
  @ApiPropertyOptional({
    maxLength: 255,
    description: 'Queda guardado en la observación del pago anulado.',
  })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  motivo?: string;
}

export class FiltroReportePeriodoDto {
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

  @ApiPropertyOptional({
    enum: [1, 2],
    description: 'Sin quincena, la lista de pendientes viene vacía (sería ambigua)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @IsIn([1, 2])
  quincena?: number;
}
