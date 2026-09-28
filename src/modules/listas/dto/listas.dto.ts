import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, Max, Min } from 'class-validator';

export class ListaIdParamDto {
  @ApiProperty({ example: 7, description: 'ID real de gen_lista' })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(Number.MAX_SAFE_INTEGER)
  id!: number;
}

export interface ListaItem {
  id: number;
  codigo: string;
  nombre: string;
  descripcion: string | null;
}

export interface ListaOpcionItem extends ListaItem {
  id_lista: number;
  valor_entero: number | null;
  orden: number;
}

export interface ListaConOpciones extends ListaItem {
  opciones: ListaOpcionItem[];
}
