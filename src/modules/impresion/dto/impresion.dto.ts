import {
  IsBoolean,
  IsString,
  IsUUID,
  MaxLength,
  IsOptional,
} from 'class-validator';

export class ConfirmarImpresionDto {
  @IsUUID() propietario!: string;
  @IsBoolean() enviado!: boolean;
  @IsOptional() @IsString() @MaxLength(500) error?: string;
}
export class ResolverImpresionDto {
  @IsBoolean() enviado!: boolean;
}
export class FirmaQzDto {
  @IsString() @MaxLength(100000) mensaje!: string;
}
