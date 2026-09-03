import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsInt, IsNotEmpty, IsNumber, IsOptional, IsString, MaxLength } from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export type ProductoEstadoFiltro = 'todos' | 'activos' | 'inactivos';

export class FiltroProductosDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({
    enum: ['todos', 'activos', 'inactivos'],
    default: 'activos',
    description: 'Filtrar por estado para los chips',
  })
  @IsOptional()
  estado?: ProductoEstadoFiltro = 'activos';

  @ApiPropertyOptional({ description: 'Filtrar por tipo de producto (1: Insumo Crudo, etc.)' })
  @IsOptional()
  @IsInt()
  tipo_producto?: number;

  @ApiPropertyOptional({ description: 'Filtrar por ID de subcategoría' })
  @IsOptional()
  @IsInt()
  id_subcategoria?: number;

  @ApiPropertyOptional({ description: 'Filtrar por ID de categoría' })
  @IsOptional()
  @IsInt()
  id_categoria?: number;
}

export class CreateProductoDto extends AuditoriaDto {
  @ApiProperty({ description: 'ID de la subcategoría', example: 1 })
  @IsInt()
  @IsNotEmpty()
  id_subcategoria!: number;

  @ApiProperty({ description: 'ID de la unidad de medida', example: 1 })
  @IsInt()
  @IsNotEmpty()
  id_unidad_medida!: number;

  @ApiPropertyOptional({ description: 'ID de la estación de impresión (obligatorio en platos/tragos)', example: 1 })
  @IsOptional()
  @IsInt()
  id_estacion?: number;

  @ApiPropertyOptional({ description: 'ID del almacén de stock (obligatorio si controla stock)', example: 1 })
  @IsOptional()
  @IsInt()
  id_almacen_stock?: number;

  @ApiProperty({ description: 'Código interno único del producto', example: 'PROD-0001' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  codigo_interno!: string;

  @ApiProperty({ description: 'Nombre del producto o plato', example: 'Lomo Saltado' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(150)
  nombre!: string;

  @ApiPropertyOptional({ description: 'Descripción detallada' })
  @IsOptional()
  @IsString()
  descripcion?: string;

  @ApiProperty({ description: 'Tipo de producto (1 a 7)', example: 3 })
  @IsInt()
  @IsNotEmpty()
  tipo_producto!: number;

  @ApiPropertyOptional({ description: 'Precio de venta', example: 35.00 })
  @IsOptional()
  @IsNumber()
  precio_venta?: number;

  @ApiPropertyOptional({ description: 'Si está afecto a IGV', default: true })
  @IsOptional()
  @IsBoolean()
  afecto_igv?: boolean;

  @ApiPropertyOptional({ description: 'Si controla stock directamente', default: false })
  @IsOptional()
  @IsBoolean()
  controla_stock?: boolean;

  @ApiPropertyOptional({ description: 'Disponible para venta en carta', default: true })
  @IsOptional()
  @IsBoolean()
  disponible_venta?: boolean;

  @ApiPropertyOptional({ description: 'Tiempo estimado de preparación en minutos', example: 15 })
  @IsOptional()
  @IsInt()
  tiempo_prep_min?: number;

  @ApiPropertyOptional({ description: 'URL de la imagen del producto' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  imagen_url?: string;
}

export class UpdateProductoDto extends AuditoriaDto {
  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @IsInt()
  id_subcategoria?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @IsInt()
  id_unidad_medida?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @IsInt()
  id_estacion?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @IsInt()
  id_almacen_stock?: number;

  @ApiPropertyOptional({ maxLength: 50 })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  codigo_interno?: string;

  @ApiPropertyOptional({ maxLength: 150 })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  nombre?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  descripcion?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  tipo_producto?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  precio_venta?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  afecto_igv?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  controla_stock?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  disponible_venta?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  tiempo_prep_min?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(255)
  imagen_url?: string;
}