import {
  BadRequestException,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { readFile } from 'node:fs/promises';
import {
  createHash,
  createSign,
  createPrivateKey,
  X509Certificate,
} from 'node:crypto';
import { isIP } from 'node:net';
import { ImpresionModel } from '../models/impresion.model';

@Injectable()
export class QzSigningLogic {
  private readonly logger = new Logger(QzSigningLogic.name);
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
    const guardado = await this.model.configuracionQz();
    if (guardado) return { certificado: guardado.certificado };
    const path = this.config.get<string>('QZ_CERTIFICATE_PATH');
    if (path) return { certificado: await readFile(path, 'utf8') };
    if (this.unsigned) return { certificado: null };
    throw new ServiceUnavailableException(
      'Configura el certificado y la clave de QZ Tray en el servidor',
    );
  }
  async configuracion() {
    const guardado = await this.model.configuracionQz();
    if (!guardado)
      return {
        configurado: false,
        origen: this.config.get('QZ_CERTIFICATE_PATH') ? 'archivo' : null,
      };
    const cert = new X509Certificate(guardado.certificado);
    return {
      configurado: true,
      origen: 'base',
      actualizado: guardado.actualizado,
      sujeto: cert.subject,
      vence: cert.validTo,
      huella: cert.fingerprint256,
    };
  }

  async guardarConfiguracion(certificado: string, clavePrivada: string) {
    try {
      const cert = new X509Certificate(certificado);
      const key = createPrivateKey(clavePrivada);
      if (
        key.asymmetricKeyType !== 'rsa' ||
        (key.asymmetricKeyDetails?.modulusLength ?? 0) < 2048
      )
        throw new Error('La clave debe ser RSA de al menos 2048 bits');
      if (!cert.checkPrivateKey(key))
        throw new Error('El certificado no corresponde a la clave privada');
      if (
        Date.now() < Date.parse(cert.validFrom) ||
        Date.now() >= Date.parse(cert.validTo)
      )
        throw new Error('El certificado está vencido o todavía no es válido');
    } catch {
      throw new BadRequestException(
        'Carga un certificado vigente y su clave privada RSA correspondiente (PEM sin contraseña, mínimo 2048 bits)',
      );
    }
    await this.model.guardarConfiguracionQz(
      certificado.trim(),
      clavePrivada.trim(),
    );
    return this.configuracion();
  }
  // QZ en el navegador sólo muestra «Failed to sign request»: el motivo real queda en el log.
  async firmar(message: string) {
    try {
      return await this.validarYFirmar(message);
    } catch (error) {
      this.logger.warn(
        `Firma QZ rechazada: ${error instanceof Error ? error.message : String(error)}`,
      );
      throw error;
    }
  }

  private async validarYFirmar(message: string) {
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
      // Se admite texto RAW y el logo del ticket como imagen base64 embebida.
      const data = params.data;
      if (
        !Array.isArray(data) ||
        !data.length ||
        data.some((item: unknown) => {
          if (!item || typeof item !== 'object') return true;
          const row = item as Record<string, unknown>;
          if (row.type !== 'raw' || typeof row.data !== 'string') return true;
          if (row.format === 'command') return row.flavor !== 'plain';
          return (
            row.format !== 'image' ||
            row.flavor !== 'base64' ||
            !/^[A-Za-z0-9+/]+={0,2}$/.test(row.data)
          );
        })
      )
        throw new BadRequestException('Sólo se permite texto de comanda RAW');
    }
    if (!(await this.model.impresoraActiva(target.host)))
      throw new BadRequestException('La IP no pertenece a una estación activa');
    const guardado = await this.model.configuracionQz();
    const path = this.config.get<string>('QZ_PRIVATE_KEY_PATH');
    if (!guardado && !path && this.unsigned) return { firma: '' };
    if (!guardado && !path)
      throw new ServiceUnavailableException(
        'Falta configurar la clave de QZ Tray',
      );
    const signer = createSign('RSA-SHA512');
    // qz-tray firma la representación hexadecimal SHA-256 del mensaje serializado.
    signer.update(createHash('sha256').update(message).digest('hex'));
    return {
      firma: signer.sign(
        guardado ? guardado.clave_privada : await readFile(path!, 'utf8'),
        'base64',
      ),
    };
  }
}
