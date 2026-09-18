import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsEmail,
  IsIn,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export type PersonaEstadoFiltro = 'todos' | 'activos' | 'inactivos';

/**
 * Filtro por rol. No es una columna: una misma persona puede ser cliente y
 * proveedor a la vez, así que esto solo acota el listado según desde dónde se
 * esté mirando.
 */
export type PersonaRolFiltro = 'todos' | 'clientes' | 'proveedores';

/** Catálogo PERSONA_TIPO. */
export const TIPO_PERSONA = { NATURAL: 1, JURIDICA: 2 } as const;

/** Catálogo DOCUMENTO_TIPO. Los números son los códigos de SUNAT. */
export const TIPO_DOCUMENTO = { DNI: 1, CE: 4, RUC: 6 } as const;

export class FiltroPersonasDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({
    enum: ['todos', 'activos', 'inactivos'],
    default: 'activos',
  })
  @IsOptional()
  estado?: PersonaEstadoFiltro = 'activos';

  @ApiPropertyOptional({
    enum: ['todos', 'clientes', 'proveedores'],
    default: 'todos',
    description: 'Acota el listado a clientes o a proveedores',
  })
  @IsOptional()
  @IsIn(['todos', 'clientes', 'proveedores'])
  rol?: PersonaRolFiltro = 'todos';

  @ApiPropertyOptional({ description: 'Filtrar clientes de un convenio puntual' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  id_convenio?: number;
}

export class BuscarPersonasDto {
  @ApiPropertyOptional({ example: '4561', description: 'Nombre, razón social o documento' })
  @IsOptional()
  @IsString()
  buscar?: string;

  @ApiPropertyOptional({ enum: ['todos', 'clientes', 'proveedores'], default: 'todos' })
  @IsOptional()
  @IsIn(['todos', 'clientes', 'proveedores'])
  rol?: PersonaRolFiltro = 'todos';

  @ApiPropertyOptional({ example: 15, default: 15, description: 'Máximo 50' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  limite?: number;
}

export class CreatePersonaDto extends AuditoriaDto {
  @ApiProperty({ enum: [1, 2], example: 1, description: '1 = natural, 2 = jurídica' })
  @IsInt()
  @IsIn([1, 2])
  tipo_persona!: number;

  @ApiProperty({ enum: [1, 4, 6], example: 1, description: '1 = DNI, 4 = CE, 6 = RUC' })
  @IsInt()
  @IsIn([1, 4, 6])
  tipo_documento!: number;

  @ApiProperty({ example: '45612345', maxLength: 20 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(20)
  num_documento!: string;

  @ApiPropertyOptional({
    example: 'Consorcio GVR S.A.C.',
    maxLength: 255,
    description: 'Obligatoria si tipo_persona = 2',
  })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  razon_social?: string;

  @ApiPropertyOptional({
    example: 'Billy',
    maxLength: 100,
    description: 'Obligatorio si tipo_persona = 1',
  })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  nombres?: string;

  @ApiPropertyOptional({
    example: 'Reaño',
    maxLength: 100,
    description: 'Obligatorio si tipo_persona = 1',
  })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  apellido_paterno?: string;

  @ApiPropertyOptional({ example: 'Vargas', maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  apellido_materno?: string;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  direccion?: string;

  @ApiPropertyOptional({ description: 'ID de gen_distrito' })
  @IsOptional()
  @IsInt()
  id_distrito?: number;

  @ApiPropertyOptional({ example: '987654321', maxLength: 20 })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  telefono?: string;

  @ApiPropertyOptional({ example: 'billy@gvr.pe', maxLength: 100 })
  @IsOptional()
  @IsEmail({}, { message: 'El correo electrónico no tiene un formato válido' })
  @MaxLength(100)
  email?: string;

  @ApiPropertyOptional({
    default: false,
    description: 'Consume en el local. Requisito para cobrarle a crédito (M12)',
  })
  @IsOptional()
  @IsBoolean()
  es_cliente?: boolean;

  @ApiPropertyOptional({
    default: false,
    description: 'Nos vende insumos. Requisito para registrarle compras (M07)',
  })
  @IsOptional()
  @IsBoolean()
  es_proveedor?: boolean;

  @ApiPropertyOptional({
    description: 'Convenio de crédito. Solo válido si es_cliente = true',
  })
  @IsOptional()
  @IsInt()
  id_convenio?: number;
}

export class UpdatePersonaDto extends AuditoriaDto {
  @ApiPropertyOptional({ enum: [1, 2] })
  @IsOptional()
  @IsInt()
  @IsIn([1, 2])
  tipo_persona?: number;

  @ApiPropertyOptional({ enum: [1, 4, 6] })
  @IsOptional()
  @IsInt()
  @IsIn([1, 4, 6])
  tipo_documento?: number;

  @ApiPropertyOptional({ maxLength: 20 })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  num_documento?: string;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  razon_social?: string;

  @ApiPropertyOptional({ maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  nombres?: string;

  @ApiPropertyOptional({ maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  apellido_paterno?: string;

  @ApiPropertyOptional({ maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  apellido_materno?: string;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  direccion?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  id_distrito?: number;

  @ApiPropertyOptional({ maxLength: 20 })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  telefono?: string;

  @ApiPropertyOptional({ maxLength: 100 })
  @IsOptional()
  @IsEmail({}, { message: 'El correo electrónico no tiene un formato válido' })
  @MaxLength(100)
  email?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  es_cliente?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  es_proveedor?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  id_convenio?: number;

  @ApiPropertyOptional({
    default: false,
    description:
      'Marcar en true para dejar a la persona SIN convenio. Hace falta porque ' +
      'mandar id_convenio en null significa "no lo estoy cambiando", no "quítalo".',
  })
  @IsOptional()
  @IsBoolean()
  quitar_convenio?: boolean;
}
