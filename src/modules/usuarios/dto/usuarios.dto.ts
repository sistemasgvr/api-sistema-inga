import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray,
  IsEmail,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';

export class CreateUsuarioDto extends AuditoriaDto {
  @ApiProperty({ example: 'jperez', maxLength: 50 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  username!: string;

  @ApiProperty({ example: 'juan.perez@inga.pe', maxLength: 100 })
  @IsEmail()
  @IsNotEmpty()
  @MaxLength(100)
  email!: string;

  @ApiProperty({ example: 'MiClave123', minLength: 8 })
  @IsString()
  @IsNotEmpty()
  @MinLength(8)
  @MaxLength(100)
  password!: string;

  @ApiPropertyOptional({ example: '1234', minLength: 4, maxLength: 10 })
  @IsOptional()
  @IsString()
  @MinLength(4)
  @MaxLength(10)
  pin?: string;

  @ApiProperty({ example: 'Juan', maxLength: 100 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  nombres!: string;

  @ApiProperty({ example: 'Pérez', maxLength: 100 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  apellidos!: string;

  @ApiPropertyOptional({ example: '987654321', maxLength: 20 })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  telefono?: string;

  @ApiPropertyOptional({ example: 1, description: 'ID de la sucursal por defecto' })
  @IsOptional()
  @IsInt()
  idSucursalDefault?: number;

  @ApiPropertyOptional({ example: [1, 2], description: 'IDs de roles asignados' })
  @IsOptional()
  @IsArray()
  @IsInt({ each: true })
  rolesIds?: number[];
}

export class UpdateUsuarioDto extends AuditoriaDto {
  @ApiPropertyOptional({ maxLength: 50 })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  username?: string;

  @ApiPropertyOptional({ maxLength: 100 })
  @IsOptional()
  @IsEmail()
  @MaxLength(100)
  email?: string;

  @ApiPropertyOptional({ minLength: 8, maxLength: 100 })
  @IsOptional()
  @IsString()
  @MinLength(8)
  @MaxLength(100)
  password?: string;

  @ApiPropertyOptional({ minLength: 4, maxLength: 10 })
  @IsOptional()
  @IsString()
  @MinLength(4)
  @MaxLength(10)
  pin?: string;

  @ApiPropertyOptional({ maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  nombres?: string;

  @ApiPropertyOptional({ maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  apellidos?: string;

  @ApiPropertyOptional({ maxLength: 20 })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  telefono?: string;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @IsInt()
  idSucursalDefault?: number;

  @ApiPropertyOptional({ example: [1, 2], description: 'IDs de roles asignados' })
  @IsOptional()
  @IsArray()
  @IsInt({ each: true })
  rolesIds?: number[];
}