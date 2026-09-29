import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
  Min,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';

export class CreateUsuarioDto extends AuditoriaDto {
  @ApiProperty({ description: 'Trabajador titular de la cuenta' })
  @IsInt()
  @Min(1)
  idTrabajador!: number;

  @ApiProperty({ example: 'jperez', maxLength: 50 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  username!: string;

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

  @ApiPropertyOptional({
    example: [1, 2],
    description: 'IDs de roles asignados',
  })
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

  @ApiPropertyOptional({
    example: [1, 2],
    description: 'IDs de roles asignados',
  })
  @IsOptional()
  @IsArray()
  @IsInt({ each: true })
  rolesIds?: number[];
}
