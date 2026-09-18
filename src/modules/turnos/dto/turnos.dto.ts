import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsIn,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

/** Catálogo TURNO_ESTADO. */
export const ESTADO_TURNO = { ABIERTO: 1, CERRADO: 2 } as const;

/** Catálogo CAJA_MOV_TIPO. */
export const TIPO_MOVIMIENTO = { INGRESO: 1, EGRESO: 2 } as const;

export class FiltroTurnosDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({ description: 'Filtrar por caja' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  id_caja?: number;

  @ApiPropertyOptional({ description: 'Filtrar por cajero' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  id_cajero?: number;

  @ApiPropertyOptional({ enum: [1, 2], description: '1 = abierto, 2 = cerrado' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @IsIn([1, 2])
  estado_turno?: number;

  @ApiPropertyOptional({ example: '2026-09-01' })
  @IsOptional()
  @IsDateString()
  fecha_desde?: string;

  @ApiPropertyOptional({ example: '2026-09-30' })
  @IsOptional()
  @IsDateString()
  fecha_hasta?: string;
}

export class AbrirTurnoDto extends AuditoriaDto {
  @ApiProperty({ example: 1, description: 'Caja física que se va a abrir' })
  @IsInt()
  @IsNotEmpty()
  id_caja!: number;

  @ApiProperty({ example: 3, description: 'Usuario que se hace cargo de la caja' })
  @IsInt()
  @IsNotEmpty()
  id_cajero!: number;

  @ApiPropertyOptional({
    example: 200,
    default: 0,
    description: 'Efectivo con el que arranca el cajón (el sencillo)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  monto_apertura?: number;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  observacion?: string;
}

export class CerrarTurnoDto extends AuditoriaDto {
  @ApiProperty({
    example: 1250.5,
    description: 'Efectivo realmente contado en el cajón al cerrar',
  })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  monto_cierre_declarado!: number;

  @ApiPropertyOptional({
    maxLength: 255,
    description: 'Sobre todo si hubo diferencia: acá se explica por qué',
  })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  observacion?: string;
}

export class CreateMovimientoDto extends AuditoriaDto {
  @ApiProperty({ enum: [1, 2], example: 2, description: '1 = ingreso, 2 = egreso' })
  @IsInt()
  @IsIn([1, 2])
  tipo_movimiento!: number;

  @ApiProperty({ example: 35.5, description: 'Siempre positivo; el signo lo da el tipo' })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01, { message: 'El monto debe ser mayor a cero' })
  monto!: number;

  @ApiProperty({ example: 'Compra de hielo', maxLength: 255 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  motivo!: string;

  @ApiPropertyOptional({ description: 'Quién autorizó el movimiento (ADMIN)' })
  @IsOptional()
  @IsInt()
  id_usuario_autoriza?: number;
}

/** Una línea del conteo: cuántos billetes o monedas de cada valor. */
export class ArqueoLineaDto {
  @ApiProperty({ example: 100, description: 'Valor del billete o moneda' })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  denominacion!: number;

  @ApiProperty({ example: 5, description: 'Cuántos hay de esa denominación' })
  @Type(() => Number)
  @IsInt()
  @Min(0)
  cantidad!: number;
}

export class GuardarArqueoDto extends AuditoriaDto {
  @ApiProperty({
    type: [ArqueoLineaDto],
    description:
      'Conteo completo. Reemplaza al anterior, no se acumula: mándalo entero cada vez.',
  })
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => ArqueoLineaDto)
  detalle!: ArqueoLineaDto[];
}
