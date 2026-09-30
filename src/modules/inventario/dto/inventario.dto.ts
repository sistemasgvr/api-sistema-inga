import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

export class DetalleMovimientoDto {
  @ApiProperty() @IsInt() @Min(1) id_producto!: number;
  @ApiProperty() @IsInt() @Min(1) id_almacen!: number;
  @ApiProperty() @IsInt() @Min(1) id_unidad_medida!: number;
  @ApiProperty()
  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(0.0001)
  @Max(9999999999.9999)
  cantidad!: number;
  @ApiProperty({ enum: [-1, 1] }) @IsIn([-1, 1]) signo!: number;
  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(0)
  @Max(99999999.9999)
  costo_unitario?: number;
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  observacion?: string;
}

export class MovimientoDto {
  @ApiProperty() @IsString() @Matches(/\S/) @MaxLength(50) codigo!: string;
  @ApiProperty() @IsInt() @Min(1) id_tipo_movimiento!: number;
  @ApiProperty() @IsInt() @Min(1) id_motivo_movimiento!: number;
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(40)
  documento_tipo?: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) documento_id?: number;
  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(1)
  id_movimiento_referencia?: number;
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  observacion?: string;
  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  confirmar?: boolean;
  @ApiProperty({ type: [DetalleMovimientoDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(500)
  @ValidateNested({ each: true })
  @Type(() => DetalleMovimientoDto)
  detalles!: DetalleMovimientoDto[];
}

export class PrepararDto {
  @ApiProperty({
    description:
      'Código único de la preparación; reintentos idénticos no duplican producción.',
  })
  @IsString()
  @Matches(/\S/)
  @MaxLength(50)
  codigo!: string;
  @ApiProperty() @IsInt() @Min(1) id_receta!: number;
  @ApiProperty() @IsInt() @Min(1) id_almacen_destino!: number;
  @ApiProperty()
  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(0.0001)
  @Max(9999999999.9999)
  cantidad!: number;
  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(1)
  id_pedido_detalle?: number;
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  observacion?: string;
}

export class FiltroInventarioDto {
  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  id_producto?: number;
  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  id_almacen?: number;
  @ApiPropertyOptional({ default: 50 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  limite = 50;
  @ApiPropertyOptional({ default: 0 })
  @Type(() => Number)
  @IsInt()
  @Min(0)
  offset = 0;
}
