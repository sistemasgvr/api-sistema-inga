import { Transform, Type } from 'class-transformer';
import { IsBoolean, IsIn, IsInt, IsOptional, Max, Min } from 'class-validator';
import { CANALES_VALIDOS } from '../constants/canales';
import type { CanalNotificacion } from '../constants/canales';

export class ListarNotificacionesDto {
  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true' || value === '1')
  @IsBoolean()
  soloNoLeidas?: boolean;

  @IsOptional()
  @IsIn(CANALES_VALIDOS)
  canal?: CanalNotificacion;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limite?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  offset?: number;
}

export class MarcarTodasLeidasDto {
  @IsOptional()
  @IsIn(CANALES_VALIDOS)
  canal?: CanalNotificacion;
}
