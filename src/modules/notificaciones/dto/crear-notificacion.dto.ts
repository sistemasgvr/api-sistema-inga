import { IsIn, IsOptional, IsString, IsNumber, IsUUID } from 'class-validator';

export class CrearNotificacionDto {
  @IsString()
  canal!: string;

  @IsString()
  titulo!: string;

  @IsString()
  mensaje!: string;

  @IsOptional()
  @IsIn(['info', 'success', 'warning', 'error'])
  severidad?: 'info' | 'success' | 'warning' | 'error';

  @IsString()
  ruta!: string;

  @IsOptional()
  @IsNumber()
  idReferencia?: number | null;

  @IsOptional()
  @IsNumber({}, { each: true })
  idsUsuario?: number[];
}
