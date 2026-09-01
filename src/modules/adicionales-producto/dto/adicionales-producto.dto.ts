import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsInt, IsNotEmpty, IsNumber, IsOptional, IsString, MaxLength } from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';

export class CreateAdicionalDto extends AuditoriaDto {
  @ApiProperty({ description: 'Nombre del adicional', example: 'Tocino Extra' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  nombre!: string;

  @ApiProperty({ description: 'Precio adicional de venta', example: 5.00 })
  @IsNumber()
  @IsNotEmpty()
  precio_adicional!: number;

  @ApiPropertyOptional({ description: 'ID del insumo que descuenta stock (opcional)', example: 12 })
  @IsOptional()
  @IsInt()
  id_producto_insumo?: number;

  @ApiPropertyOptional({ description: 'Cantidad del insumo a descontar', example: 30.00 })
  @IsOptional()
  @IsNumber()
  cantidad_insumo?: number;

  @ApiPropertyOptional({ description: 'ID de la unidad de medida del insumo', example: 3 })
  @IsOptional()
  @IsInt()
  id_unidad_medida?: number;
}

export class UpdateAdicionalDto extends AuditoriaDto {
  @ApiPropertyOptional({ maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  nombre?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  precio_adicional?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  id_producto_insumo?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  cantidad_insumo?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  id_unidad_medida?: number;
}