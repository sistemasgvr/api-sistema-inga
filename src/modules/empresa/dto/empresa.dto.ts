import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

const recortar = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

export class GuardarEmpresaDto {
  @ApiProperty({ example: '20123456789' })
  @Transform(recortar)
  @Matches(/^\d{11}$/, { message: 'El RUC debe tener 11 dígitos' })
  ruc!: string;

  @ApiProperty({ example: 'RESTAURANTE INGA S.A.C.', maxLength: 255 })
  @Transform(recortar)
  @IsString()
  @IsNotEmpty({ message: 'La razón social es obligatoria' })
  @MaxLength(255)
  razonSocial!: string;

  @ApiPropertyOptional({ example: 'INGA', maxLength: 255 })
  @Transform(recortar)
  @IsOptional()
  @IsString()
  @MaxLength(255)
  nombreComercial?: string;

  @ApiPropertyOptional({ example: 'Av. Principal 123 - Lima' })
  @Transform(recortar)
  @IsOptional()
  @IsString()
  @MaxLength(300)
  direccion?: string;

  @ApiPropertyOptional({
    description:
      'Distrito del domicilio fiscal (gen_distrito). Su ubigeo es obligatorio para emitir a SUNAT',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  idDistrito?: number;

  @ApiPropertyOptional({
    example: 18,
    description:
      'Tasa de IGV en % según el régimen vigente. Se aplica a los pedidos que se abran desde ahora',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(100)
  tasaIgv?: number;
}

export class BuscarDistritoDto {
  @ApiPropertyOptional({ example: 'miraflores' })
  @Transform(recortar)
  @IsOptional()
  @IsString()
  @MaxLength(100)
  buscar?: string;
}
