import { ApiProperty } from '@nestjs/swagger';

export class OpcionCatalogoDto {
  @ApiProperty({ description: 'ID de la opción', example: 1 })
  id!: number;

  @ApiProperty({ description: 'Código único de la opción', example: 'CRUDO' })
  codigo!: string;

  @ApiProperty({ description: 'Nombre o etiqueta legible', example: 'Almacén de insumos' })
  nombre!: string;

  @ApiProperty({ description: 'Valor entero asignado en la base de datos', example: 1 })
  valor_entero!: number;

  @ApiProperty({ description: 'Orden de despliegue en combos', example: 1 })
  orden!: number;
}

export class RespuestaOpcionesCatalogoDto {
  @ApiProperty({ type: [OpcionCatalogoDto] })
  data!: OpcionCatalogoDto[];
}