import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsEmail,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export class LoginDto {
  @ApiProperty({
    example: 'geraldine@gmail.com',
    description: 'Correo electrónico del usuario',
  })
  @IsEmail({}, { message: 'El correo electrónico no es válido' })
  @IsNotEmpty()
  @MaxLength(150)
  email!: string;

  @ApiProperty({ example: '123456' })
  @IsString()
  @IsNotEmpty()
  password!: string;

  @ApiPropertyOptional({ example: '192.168.1.1' })
  @IsOptional()
  @IsString()
  @MaxLength(45)
  ip?: string;

  @ApiPropertyOptional({ example: 'Mozilla/5.0...' })
  @IsOptional()
  @IsString()
  @MaxLength(512)
  userAgent?: string;
}

export class CambiarSucursalDto {
  @ApiProperty({
    example: 2,
    description: 'Sucursal asignada al usuario en la que va a trabajar',
  })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  idSucursal!: number;
}
