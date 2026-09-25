import { ApiProperty } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import { IsInt, IsString, Matches, Max, MaxLength, Min } from 'class-validator';

export class ListaIdParamDto {
  @ApiProperty({ example: 7, description: 'ID real de gen_lista' })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(Number.MAX_SAFE_INTEGER)
  id!: number;
}

export class ListaCodigoParamDto {
  @ApiProperty({ example: 'MESA_ESTADO', maxLength: 50 })
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toUpperCase() : value,
  )
  @IsString()
  @MaxLength(50)
  @Matches(/^[A-Z][A-Z0-9_]*$/)
  codigo!: string;
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
