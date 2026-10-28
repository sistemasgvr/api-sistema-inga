import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

const recortar = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

const FECHA = /^\d{4}-\d{2}-\d{2}$/;

export class GuardarConfiguracionSunatDto {
  @ApiPropertyOptional({
    description:
      'Token de la empresa en APIsPERU (no caduca). Vacío u omitido conserva el actual',
  })
  @Transform(recortar)
  @IsOptional()
  @IsString()
  @MaxLength(4000)
  tokenEmision?: string;

  @ApiPropertyOptional({
    enum: [1, 2],
    description: '1 beta (pruebas), 2 producción',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @IsIn([1, 2])
  idAmbiente?: number;

  @ApiPropertyOptional({
    description:
      'Usuario SOL secundario (RUC + usuario, ej. 20123456789MODDATOS)',
  })
  @Transform(recortar)
  @IsOptional()
  @IsString()
  @MaxLength(50)
  usuarioSol?: string;

  @ApiPropertyOptional({ description: 'Clave SOL del usuario secundario' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  claveSol?: string;

  @ApiPropertyOptional({
    example: 3,
    description: 'Días desde la emisión para enviar la boleta a SUNAT',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(30)
  diasLimiteEnvioBoleta?: number;

  @ApiPropertyOptional({
    example: 7,
    description: 'Días desde la emisión para enviar la factura a SUNAT',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(30)
  diasLimiteEnvioFactura?: number;
}

export class SubirCertificadoDto {
  @ApiProperty({ description: 'Contraseña del archivo .pfx / .p12' })
  @IsString()
  @IsNotEmpty({ message: 'Ingrese la contraseña del certificado' })
  @MaxLength(200)
  clave!: string;
}

export class FechaSunatDto {
  @ApiPropertyOptional({
    example: '2026-10-28',
    description: 'Día de emisión (Lima). Por defecto, hoy',
  })
  @IsOptional()
  @Matches(FECHA, { message: 'La fecha debe tener el formato AAAA-MM-DD' })
  fecha?: string;
}

export class EnviarDiaDto {
  @ApiProperty({ example: '2026-10-28', description: 'Día de emisión (Lima)' })
  @Matches(FECHA, { message: 'La fecha debe tener el formato AAAA-MM-DD' })
  fecha!: string;
}

export class BandejaSunatDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({
    description:
      'Estado SUNAT (1 pendiente, 2 aceptado, 3 rechazado, 4 anulado, 5 en proceso). Por defecto: pendientes, en proceso y rechazados',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @IsIn([1, 2, 3, 4, 5])
  estado_sunat?: number;

  @ApiPropertyOptional({ description: '1 boleta, 2 factura' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @IsIn([1, 2])
  tipo_comprobante?: number;
}

export class FiltroLotesDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({ example: '2026-10-28' })
  @IsOptional()
  @Matches(FECHA, { message: 'La fecha debe tener el formato AAAA-MM-DD' })
  fecha?: string;

  @ApiPropertyOptional({
    description: '1 resumen diario (RC), 2 comunicación de baja (RA)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @IsIn([1, 2])
  tipo_lote?: number;
}

export class BajaSunatDto {
  @ApiProperty({ example: 'ERROR EN EL RUC DEL CLIENTE', maxLength: 100 })
  @Transform(recortar)
  @IsString()
  @IsNotEmpty({ message: 'Indique el motivo de la baja' })
  @MaxLength(100)
  motivo!: string;
}
