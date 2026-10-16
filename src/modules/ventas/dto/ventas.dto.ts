import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsDateString,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class FiltroVentasDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({
    example: '2026-10-01',
    description: 'Fecha de cobro desde (Lima)',
  })
  @IsOptional()
  @IsDateString()
  fecha_desde?: string;

  @ApiPropertyOptional({
    example: '2026-10-31',
    description: 'Fecha de cobro hasta (Lima)',
  })
  @IsOptional()
  @IsDateString()
  fecha_hasta?: string;

  @ApiPropertyOptional({
    description:
      '0 sin comprobante (crédito), 1 boleta, 2 factura, 3 nota de venta',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @IsIn([0, 1, 2, 3])
  tipo_comprobante?: number;

  @ApiPropertyOptional({
    description: '1 efectivo, 2 Yape, 3 tarjeta, 4 crédito',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  medio_pago?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  id_caja?: number;
}

export class CambiarMedioPagoDto {
  @ApiProperty({
    enum: [1, 2, 3],
    description: '1 efectivo, 2 Yape, 3 tarjeta',
  })
  @IsInt()
  @IsIn([1, 2, 3])
  medio_pago!: number;
}

export class ReemitirComprobanteDto {
  @ApiProperty({
    enum: [1, 2, 3],
    description: '1 boleta, 2 factura, 3 nota de venta',
  })
  @IsInt()
  @IsIn([1, 2, 3])
  tipo_comprobante!: number;

  @ApiPropertyOptional({
    description: 'DNI (boleta, opcional) o RUC (factura)',
  })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  documento?: string;
}
