import { ApiProperty } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsBoolean, IsNotEmpty, IsString, MaxLength } from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';

export class CreateTipoProductoDto extends AuditoriaDto {
  @ApiProperty()
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  @IsNotEmpty()
  @MaxLength(150)
  nombre!: string;

  @ApiProperty({ default: false })
  @IsBoolean()
  permite_venta!: boolean;
  @ApiProperty({ default: false })
  @IsBoolean()
  requiere_receta!: boolean;
  @ApiProperty({ default: false })
  @IsBoolean()
  requiere_estacion!: boolean;
  @ApiProperty({ default: true })
  @IsBoolean()
  permite_stock_inicial!: boolean;
}

export interface TipoProducto {
  id: number;
  nombre: string;
  permite_venta: boolean;
  requiere_receta: boolean;
  requiere_estacion: boolean;
  permite_stock_inicial: boolean;
}
