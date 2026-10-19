import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import {
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
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

  @ApiPropertyOptional({ example: 'Av. Principal 123 - Lima' })
  @Transform(recortar)
  @IsOptional()
  @IsString()
  @MaxLength(300)
  direccion?: string;
}
