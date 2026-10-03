import {
  BadRequestException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { readFile } from 'node:fs/promises';
import { createHash, createSign } from 'node:crypto';
import { isIP } from 'node:net';
import { ImpresionModel } from '../models/impresion.model';

@Injectable()
export class QzSigningLogic {
  constructor(
    private readonly config: ConfigService,
    private readonly model: ImpresionModel,
  ) {}
  private get unsigned() {
    return (
      this.config.get('NODE_ENV') !== 'production' &&
      this.config.get('QZ_ALLOW_UNSIGNED') === 'true'
    );
  }
  async certificado() {
    const path = this.config.get<string>('QZ_CERTIFICATE_PATH');
    if (path) return { certificado: await readFile(path, 'utf8') };
    if (this.unsigned) return { certificado: null };
    throw new ServiceUnavailableException(
      'Configura el certificado y la clave de QZ Tray en el servidor',
    );
  }
  async firmar(message: string) {
    let value: {
      call?: string;
      timestamp?: number;
      params?: Record<string, unknown>;
    };
    try {
      value = JSON.parse(message) as typeof value;
    } catch {
      throw new BadRequestException('Mensaje QZ inválido');
    }
    if (
      !value ||
      !Number.isFinite(value.timestamp) ||
      Math.abs(Date.now() - Number(value.timestamp)) > 60000
    )
      throw new BadRequestException('Mensaje QZ expirado');
    const params = value.params ?? {};
    const target =
      value.call === 'print'
        ? (params.printer as Record<string, unknown>)
        : params;
    if (
      !['print', 'socket.open', 'socket.close'].includes(value.call ?? '') ||
      !target ||
      typeof target.host !== 'string' ||
      !isIP(target.host) ||
      target.port !== 9100
    )
      throw new BadRequestException('Operación QZ no permitida');
    if (value.call === 'print') {
      // Impide firmar lecturas de archivos/URLs u otros tipos de operación QZ.
      const data = params.data;
      if (
        !Array.isArray(data) ||
        !data.length ||
        data.some((item: unknown) => {
          if (!item || typeof item !== 'object') return true;
          const row = item as Record<string, unknown>;
          return (
            row.type !== 'raw' ||
            row.format !== 'command' ||
            row.flavor !== 'plain' ||
            typeof row.data !== 'string'
          );
        })
      )
        throw new BadRequestException('Sólo se permite texto de comanda RAW');
    }
    if (!(await this.model.impresoraActiva(target.host)))
      throw new BadRequestException('La IP no pertenece a una estación activa');
    const path = this.config.get<string>('QZ_PRIVATE_KEY_PATH');
    if (!path && this.unsigned) return { firma: '' };
    if (!path)
      throw new ServiceUnavailableException(
        'Falta configurar la clave de QZ Tray',
      );
    const signer = createSign('RSA-SHA512');
    // qz-tray firma la representación hexadecimal SHA-256 del mensaje serializado.
    signer.update(createHash('sha256').update(message).digest('hex'));
    return { firma: signer.sign(await readFile(path, 'utf8'), 'base64') };
  }
}
