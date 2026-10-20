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
  /** El ticket no salió de esta PC: vuelve a «pendiente» en lugar de «revision». */
  @IsOptional() @IsBoolean() reintentable?: boolean;
}
export class ResolverImpresionDto {
  @IsBoolean() enviado!: boolean;
}
export class FirmaQzDto {
  @IsString() @MaxLength(100000) mensaje!: string;
}
