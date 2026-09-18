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

/**
 * Forma de pago por línea. No reutilizo el catálogo MEDIO_PAGO porque acá el
 * valor 3 es CRÉDITO (genera deuda), mientras que en MEDIO_PAGO el 3 es
 * tarjeta. Son dominios distintos y mezclarlos sería una trampa.
 */
export const FORMA_PAGO = {
  EFECTIVO: 1,
  YAPE: 2,
  CREDITO: 3,
} as const;

export type InsumoEstadoFiltro = 'todos' | 'activos' | 'inactivos';

/* -------------------------------- Insumos -------------------------------- */

export class FiltroInsumosDto {
  @ApiPropertyOptional({ description: 'Busca por nombre del insumo' })
  @IsOptional()
  @IsString()
  buscar?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  id_categoria?: number;

  @ApiPropertyOptional({
    enum: ['todos', 'activos', 'inactivos'],
    default: 'activos',
  })
  @IsOptional()
  estado?: InsumoEstadoFiltro = 'activos';
}

export class CreateInsumoDto extends AuditoriaDto {
  @ApiProperty({ example: 2 })
  @IsInt()
  @IsNotEmpty()
  id_categoria!: number;

  @ApiProperty({ example: 'Sal', maxLength: 150 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(150)
  nombre!: string;

  @ApiPropertyOptional({
    example: 3.5,
    default: 0,
    description: 'Solo sugiere el precio al comprar; se actualiza con cada compra.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  precio_referencial?: number;

  @ApiPropertyOptional({
    description: 'A quién se le suele comprar. Se preselecciona al marcar crédito.',
  })
  @IsOptional()
  @IsInt()
  id_proveedor_habitual?: number;
}

export class UpdateInsumoDto extends AuditoriaDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  id_categoria?: number;

  @ApiPropertyOptional({ maxLength: 150 })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  nombre?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  precio_referencial?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  id_proveedor_habitual?: number;

  @ApiPropertyOptional({
    default: false,
    description:
      'Marcar en true para dejar el insumo SIN proveedor habitual. Hace falta ' +
      'porque mandar id_proveedor_habitual en null significa "no lo cambies".',
  })
  @IsOptional()
  @IsBoolean()
  quitar_proveedor?: boolean;
}

/* ------------------------------ Gasto del día ----------------------------- */

export class AbrirDiaDto extends AuditoriaDto {
  @ApiPropertyOptional({
    example: '2026-09-18',
    description: 'Por defecto, hoy. Si el día ya existe lo devuelve tal cual.',
  })
  @IsOptional()
  @IsDateString()
  fecha_gasto?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  id_sucursal?: number;

  @ApiPropertyOptional({
    description: 'Turno de caja. Necesario para poder registrar compras en efectivo.',
  })
  @IsOptional()
  @IsInt()
  id_turno?: number;
}

export class CreateLineaDto extends AuditoriaDto {
  @ApiProperty({ example: 15 })
  @IsInt()
  @IsNotEmpty()
  id_insumo!: number;

  @ApiProperty({ example: 2.5 })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(0.0001, { message: 'La cantidad debe ser mayor a cero' })
  cantidad!: number;

  @ApiProperty({ example: 4.5 })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  precio_unitario!: number;

  @ApiPropertyOptional({
    enum: [1, 2, 3],
    default: 1,
    description:
      '1 efectivo (exige turno abierto), 2 Yape, 3 crédito (exige proveedor y genera deuda en CxP)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @IsIn([1, 2, 3])
  forma_pago?: number;

  @ApiPropertyOptional({
    description: 'Se elige al comprar, no viene del insumo. El mismo producto varía.',
  })
  @IsOptional()
  @IsInt()
  id_unidad_medida?: number;

  @ApiPropertyOptional({
    description: 'Obligatorio cuando forma_pago = 3 (crédito).',
  })
  @IsOptional()
  @IsInt()
  id_proveedor?: number;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  observacion?: string;
}

export class AnularLineaDto extends AuditoriaDto {
  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  motivo?: string;
}

export class FiltroDiasDto extends FiltroPaginacionDto {
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

  @ApiPropertyOptional({ example: '2026-09-01' })
  @IsOptional()
  @IsDateString()
  fecha_desde?: string;

  @ApiPropertyOptional({ example: '2026-09-30' })
  @IsOptional()
  @IsDateString()
  fecha_hasta?: string;
}

export class FiltroReporteDiaDto {
  @ApiPropertyOptional({ description: 'Por defecto, hoy' })
  @IsOptional()
  @IsDateString()
  fecha_gasto?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  id_sucursal?: number;
}
