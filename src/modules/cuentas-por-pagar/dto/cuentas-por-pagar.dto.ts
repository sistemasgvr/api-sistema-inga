import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsBoolean,
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

/** Tipos de movimiento, espejo de cxc_movimiento. */
export const TIPO_MOVIMIENTO_CXP = {
  CARGO: 1,
  ABONO: 2,
  AJUSTE: 3,
} as const;

export class FiltroSaldosDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({
    default: false,
    description:
      'true = solo proveedores a los que se les debe. El dashboard lo usa así; ' +
      'la pantalla de proveedores los lista todos.',
  })
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  solo_con_deuda?: boolean;
}

export class FiltroMovimientosCxpDto extends FiltroPaginacionDto {
  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  id_persona?: number;

  @ApiPropertyOptional({ enum: [1, 2, 3], description: '1 cargo, 2 abono, 3 ajuste' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @IsIn([1, 2, 3])
  tipo_movimiento?: number;

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

  @ApiPropertyOptional({ description: 'Semana ISO del año (1-53)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(53)
  semana?: number;

  @ApiPropertyOptional({ example: '2026-09-01' })
  @IsOptional()
  @IsDateString()
  fecha_desde?: string;

  @ApiPropertyOptional({ example: '2026-09-30' })
  @IsOptional()
  @IsDateString()
  fecha_hasta?: string;
}

export class CreateCargoDto extends AuditoriaDto {
  @ApiProperty({ example: 12, description: 'Debe ser una persona con es_proveedor = true' })
  @IsInt()
  @IsNotEmpty()
  id_persona!: number;

  @ApiProperty({ example: 350.0 })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01, { message: 'El monto debe ser mayor a cero' })
  monto!: number;

  @ApiPropertyOptional({
    example: '2026-09-15',
    description: 'Por defecto, hoy. De ella se derivan el año, mes y semana.',
  })
  @IsOptional()
  @IsDateString()
  fecha_movimiento?: string;

  @ApiPropertyOptional({ maxLength: 50 })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  num_comprobante?: string;

  @ApiPropertyOptional({
    description:
      'Gasto diario (M14) que originó el cargo. Lo usará ese módulo cuando exista.',
  })
  @IsOptional()
  @IsInt()
  id_gasto_diario?: number;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  observacion?: string;
}

export class CreateAbonoDto extends AuditoriaDto {
  @ApiProperty({ example: 12 })
  @IsInt()
  @IsNotEmpty()
  id_persona!: number;

  @ApiProperty({
    example: 1000.0,
    description: 'No puede superar la deuda pendiente del proveedor',
  })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01, { message: 'El monto debe ser mayor a cero' })
  monto!: number;

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

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fecha_movimiento?: string;

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

export class CreateAjusteDto extends AuditoriaDto {
  @ApiProperty({ example: 12 })
  @IsInt()
  @IsNotEmpty()
  id_persona!: number;

  @ApiProperty({
    example: -50.0,
    description:
      'Lleva signo: positivo aumenta la deuda, negativo la reduce. No puede ser cero.',
  })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  monto!: number;

  @ApiProperty({
    example: 'Nota de crédito por devolución de mercadería',
    maxLength: 255,
    description: 'Obligatorio: sin él, nadie sabe después por qué cambió el saldo.',
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  motivo!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fecha_movimiento?: string;
}

export class AnularMovimientoCxpDto extends AuditoriaDto {
  @ApiPropertyOptional({
    maxLength: 255,
    description: 'Queda guardado en la observación del movimiento anulado.',
  })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  motivo?: string;
}

export class FiltroReporteCxpDto {
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
