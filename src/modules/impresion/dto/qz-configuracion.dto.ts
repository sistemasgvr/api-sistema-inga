import { IsString, MaxLength, MinLength } from 'class-validator';

export class QzConfiguracionDto {
  @IsString() @MinLength(1) @MaxLength(32000) certificado!: string;
  @IsString() @MinLength(1) @MaxLength(16000) clavePrivada!: string;
}
