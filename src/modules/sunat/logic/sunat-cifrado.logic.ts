import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  createCipheriv,
  createDecipheriv,
  createHash,
  randomBytes,
} from 'node:crypto';

const VERSION = 'v1';

/**
 * Cifra las credenciales SUNAT (token APIsPERU, clave SOL, certificado) con
 * AES-256-GCM. La llave sale de SUNAT_CRYPTO_KEY y nunca se guarda en la base:
 * sin ella los valores cifrados no se pueden leer.
 */
@Injectable()
export class SunatCifradoLogic {
  private readonly llave: Buffer | null;

  constructor(config: ConfigService) {
    const secreto = config.get<string>('SUNAT_CRYPTO_KEY')?.trim();
    this.llave = secreto ? createHash('sha256').update(secreto).digest() : null;
  }

  configurado() {
    return this.llave !== null;
  }

  cifrar(valor: string): string {
    const llave = this.requerida();
    const iv = randomBytes(12);
    const cifrador = createCipheriv('aes-256-gcm', llave, iv);
    const datos = Buffer.concat([
      cifrador.update(valor, 'utf8'),
      cifrador.final(),
    ]);
    return [
      VERSION,
      iv.toString('base64'),
      cifrador.getAuthTag().toString('base64'),
      datos.toString('base64'),
    ].join('.');
  }

  descifrar(valor: string): string {
    const llave = this.requerida();
    const [version, iv, etiqueta, datos] = valor.split('.');
    if (version !== VERSION || !iv || !etiqueta || datos === undefined)
      throw new ServiceUnavailableException(
        'Credencial SUNAT con formato desconocido: vuelva a registrarla',
      );
    try {
      const descifrador = createDecipheriv(
        'aes-256-gcm',
        llave,
        Buffer.from(iv, 'base64'),
      );
      descifrador.setAuthTag(Buffer.from(etiqueta, 'base64'));
      return Buffer.concat([
        descifrador.update(Buffer.from(datos, 'base64')),
        descifrador.final(),
      ]).toString('utf8');
    } catch {
      throw new ServiceUnavailableException(
        'No se pudo descifrar la credencial SUNAT: SUNAT_CRYPTO_KEY cambió; vuelva a registrar las credenciales',
      );
    }
  }

  private requerida(): Buffer {
    if (!this.llave)
      throw new ServiceUnavailableException(
        'Defina SUNAT_CRYPTO_KEY en el .env del API para guardar credenciales SUNAT',
      );
    return this.llave;
  }
}
