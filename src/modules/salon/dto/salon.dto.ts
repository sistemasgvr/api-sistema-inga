import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

const trim = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

export class FiltroSalonDto extends FiltroPaginacionDto {
  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  id_sucursal?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  id_salon?: number;

  @ApiPropertyOptional({ enum: ['activos', 'inactivos', 'todos'] })
  @IsOptional()
  @IsIn(['activos', 'inactivos', 'todos'])
  estado: 'activos' | 'inactivos' | 'todos' = 'activos';
}

export class CreateSalonDto {
  @ApiProperty()
  @IsInt()
  @Min(1)
  id_sucursal!: number;

  @ApiProperty()
  @Transform(trim)
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  codigo!: string;

  @ApiProperty()
  @Transform(trim)
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  nombre!: string;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(10000)
  posicion_x?: number;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(10000)
  posicion_y?: number;

  @ApiPropertyOptional({ default: 200 })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(200)
  @Max(5000)
  ancho?: number;

  @ApiPropertyOptional({ default: 150 })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(150)
  @Max(5000)
  alto?: number;
}

export class UpdateSalonDto extends PartialType(CreateSalonDto, {
  skipNullProperties: false,
}) {}

export class CreateMesaDto {
  @ApiProperty()
  @IsInt()
  @Min(1)
  id_salon!: number;

  @ApiProperty()
  @Transform(trim)
  @IsString()
  @IsNotEmpty()
  @MaxLength(20)
  codigo!: string;

  @ApiProperty({ default: 2 })
  @IsInt()
  @Min(1)
  @Max(100)
  capacidad_personas!: number;

  @ApiPropertyOptional({
    enum: [1, 2, 3, 4],
    description: '1 Libre, 2 Ocupada, 3 Por cobrar, 4 Inhabilitada',
  })
  @IsOptional()
  @IsInt()
  @IsIn([1, 2, 3, 4])
  estado_mesa?: number;
}

export class UpdateMesaDto extends PartialType(CreateMesaDto, {
  skipNullProperties: false,
}) {}
