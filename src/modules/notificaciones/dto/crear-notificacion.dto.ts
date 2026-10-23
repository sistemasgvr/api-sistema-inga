import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
} from 'class-validator';
import { CANALES_VALIDOS, SEVERIDADES } from '../constants/canales';
import type {
  CanalNotificacion,
  SeveridadNotificacion,
} from '../constants/canales';

export class CrearNotificacionDto {
  @IsIn(CANALES_VALIDOS)
  canal!: CanalNotificacion;

  @IsString()
  @MaxLength(120)
  titulo!: string;

  @IsString()
  mensaje!: string;

  @IsOptional()
  @IsIn(SEVERIDADES)
  severidad?: SeveridadNotificacion;

  // Solo rutas internas del front: empiezan con "/" y no llevan esquema.
  @IsString()
  @MaxLength(255)
  @Matches(/^\/(?!\/)[^\s]*$/, {
    message: 'La ruta debe ser interna (ej. /ventas)',
  })
  ruta!: string;

  @IsOptional()
  @IsInt()
  idReferencia?: number | null;

  /** Si se indica, solo estos usuarios ven la notificación. */
  @IsOptional()
  @IsInt({ each: true })
  idsUsuario?: number[];
}
