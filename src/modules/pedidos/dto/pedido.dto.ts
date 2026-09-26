import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  ArrayMaxSize,
  ArrayUnique,
  IsArray,
  IsIn,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

export class AbrirPedidoDto {
  @ApiProperty({ enum: [1, 2, 3] })
  @IsInt()
  @IsIn([1, 2, 3])
  tipo_pedido!: number;

  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) id_mesa?: number;
  @ApiPropertyOptional({
    description:
      'Obligatoria para pedidos sin mesa; se deriva del salón para pedidos en mesa.',
  })
  @IsOptional()
  @IsInt()
  @Min(1)
  id_sucursal?: number;
  @ApiProperty() @IsInt() @Min(1) id_mozo!: number;
  @ApiProperty() @IsInt() @Min(1) id_turno!: number;
  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(1000)
  num_comensales?: number;
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  observacion?: string;
}

export class AdicionalPedidoDto {
  @ApiProperty() @IsInt() @Min(1) id_adicional!: number;
}

export class AgregarItemDto {
  @ApiProperty() @IsInt() @Min(1) id_producto!: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) id_receta?: number;
  @ApiProperty()
  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(0.0001)
  @Max(9999999999.9999)
  cantidad!: number;
  @ApiPropertyOptional({
    description: 'Si se omite se usa el precio vigente del producto.',
  })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(9999999999.99)
  precio_unitario?: number;
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  observacion?: string;
  @ApiPropertyOptional({ type: [AdicionalPedidoDto] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50)
  @ArrayUnique((a: AdicionalPedidoDto) => a.id_adicional)
  @ValidateNested({ each: true })
  @Type(() => AdicionalPedidoDto)
  adicionales?: AdicionalPedidoDto[];
  @ApiPropertyOptional({
    type: [Number],
    description:
      'IDs de pro_receta_insumo opcionales o elegidos en grupos de sustitución.',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(100)
  @ArrayUnique()
  @IsInt({ each: true })
  @Min(1, { each: true })
  insumos_seleccionados?: number[];
}

export class EditarItemDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(0.0001)
  @Max(9999999999.9999)
  cantidad?: number;
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  observacion?: string;
}

export class AnularPedidoDto {
  @ApiProperty({
    description:
      'Debe coincidir con el usuario autenticado, con rol ADMIN o CAJERO activo.',
  })
  @IsInt()
  @Min(1)
  id_usuario_autoriza!: number;
  @ApiProperty() @IsString() @IsNotEmpty() @MaxLength(2000) motivo!: string;
}

export class EstadoPedidoDto {
  @ApiProperty({ enum: [2, 3, 4, 5] })
  @IsInt()
  @IsIn([2, 3, 4, 5])
  estado_pedido!: number;
  @ApiPropertyOptional({ description: 'Requerido para ANULADO.' })
  @IsOptional()
  @IsInt()
  @Min(1)
  id_usuario_autoriza?: number;
  @ApiPropertyOptional({ description: 'Requerido para ANULADO.' })
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(2000)
  motivo?: string;
}
