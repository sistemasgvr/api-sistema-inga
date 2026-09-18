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

/** Tipos de movimiento, espejo de cxp_movimiento. */
export const TIPO_MOVIMIENTO_CXC = {
  CONSUMO: 1,
  ABONO: 2,
  AJUSTE: 3,
} as const;

/**
 * La quincena es el corte del negocio: días 1-15 y 16-fin de mes.
 * No la pido al registrar (la deduzco de la fecha en SQL), pero sí la acepto
 * como filtro, porque el reporte que se le manda a cada empresa es por quincena.
 */
export class FiltroSaldosCxcDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({
    default: false,
    description:
      'true = solo clientes que nos deben. El dashboard lo usa así; la pantalla ' +
      'de convenios los lista a todos, incluidos los que están en cero.',
  })
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  solo_con_deuda?: boolean;

  @ApiPropertyOptional({
    description: 'Filtra por empresa del consorcio. El corte se factura por empresa.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  id_convenio?: number;
}

export class FiltroMovimientosCxcDto extends FiltroPaginacionDto {
  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  id_persona?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  id_convenio?: number;

  @ApiPropertyOptional({ enum: [1, 2, 3], description: '1 consumo, 2 abono, 3 ajuste' })
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

  @ApiPropertyOptional({ enum: [1, 2], description: '1 = días 1-15, 2 = días 16-fin' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @IsIn([1, 2])
  quincena?: number;

  @ApiPropertyOptional({
    default: false,
    description: 'Los anulados ensucian la vista diaria, pero hacen falta para auditar.',
  })
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  incluir_anulados?: boolean;
}

export class CreateConsumoDto extends AuditoriaDto {
  @ApiProperty({
    example: 12,
    description: 'Debe ser una persona con es_cliente = true y convenio activo',
  })
  @IsInt()
  @IsNotEmpty()
  id_persona!: number;

  @ApiProperty({ example: 18.5 })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01, { message: 'El monto debe ser mayor a cero' })
  monto!: number;

  @ApiPropertyOptional({
    example: '2026-09-15',
    description: 'Por defecto, hoy. De ella se derivan el año, mes y quincena.',
  })
  @IsOptional()
  @IsDateString()
  fecha_movimiento?: string;

  @ApiPropertyOptional({
    description: 'Pedido que originó el consumo. Lo usará M12 cuando exista.',
  })
  @IsOptional()
  @IsInt()
  id_pedido?: number;

  @ApiPropertyOptional({ description: 'Pago del pedido con medio_pago = crédito.' })
  @IsOptional()
  @IsInt()
  id_pago?: number;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  observacion?: string;
}

export class CreateAbonoCxcDto extends AuditoriaDto {
  @ApiProperty({ example: 12 })
  @IsInt()
  @IsNotEmpty()
  id_persona!: number;

  @ApiProperty({
    example: 250.0,
    description: 'No puede superar la deuda pendiente del cliente',
  })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01, { message: 'El monto debe ser mayor a cero' })
  monto!: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fecha_movimiento?: string;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  observacion?: string;
}

export class CreateAjusteCxcDto extends AuditoriaDto {
  @ApiProperty({ example: 12 })
  @IsInt()
  @IsNotEmpty()
  id_persona!: number;

  @ApiProperty({
    example: -12.0,
    description:
      'Lleva signo: positivo aumenta la deuda, negativo la reduce. No puede ser cero.',
  })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  monto!: number;

  @ApiProperty({
    example: 'Se cargó dos veces el almuerzo del 12/09',
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

export class AnularMovimientoCxcDto extends AuditoriaDto {
  @ApiPropertyOptional({
    maxLength: 255,
    description: 'Queda guardado en la observación del movimiento anulado.',
  })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  motivo?: string;
}

export class FiltroEstadoCuentaDto {
  @ApiPropertyOptional({ description: 'Sin período, trae el historial completo' })
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
}

export class FiltroReporteCxcDto extends FiltroEstadoCuentaDto {
  @ApiPropertyOptional({
    description: 'Una sola empresa. Sin él, el reporte trae todas agrupadas.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  id_convenio?: number;
}
