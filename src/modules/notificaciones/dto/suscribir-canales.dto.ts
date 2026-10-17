import { IsArray, IsString } from 'class-validator';

export class SuscribirCanalesDto {
  @IsArray()
  @IsString({ each: true })
  canales!: string[];
}
