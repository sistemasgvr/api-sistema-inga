import { ConfigService } from '@nestjs/config';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import {
  createHash,
  generateKeyPairSync,
  verify,
  X509Certificate,
} from 'node:crypto';
import { QzSigningLogic } from '../../src/modules/impresion/logic/qz-signing.logic';
import { ImpresionModel } from '../../src/modules/impresion/models/impresion.model';
import { ImpresionController } from '../../src/modules/impresion/controllers/impresion.controller';
import { PERMISOS_KEY } from '../../src/common/decorators/permisos.decorator';
import { PermisoBanderas } from '../../src/common/constants/permiso-banderas';

// Este par es público, exclusivo de pruebas y nunca debe usarse para imprimir.
const certificado = readFileSync(
  join(__dirname, 'fixtures/test-only-cert.pem'),
  'utf8',
);
const clave = readFileSync(
  join(__dirname, 'fixtures/test-only-key.pem'),
  'utf8',
);
describe('Configuración QZ en base de datos', () => {
  it('exige permiso de edición en lectura de configuración y reemplazo', () => {
    for (const handler of [ImpresionController.prototype.configuracionQz, ImpresionController.prototype.guardarConfiguracionQz]) {
      expect(Reflect.getMetadata(PERMISOS_KEY, handler)).toEqual([PermisoBanderas.ESTACIONES_EDITAR]);
    }
  });
  const model = {
    configuracionQz: jest.fn(),
    guardarConfiguracionQz: jest.fn(),
    impresoraActiva: jest.fn(),
  };
  const service = new QzSigningLogic(
    new ConfigService({ NODE_ENV: 'production' }),
    model as unknown as ImpresionModel,
  );
  beforeEach(() => {
    jest.resetAllMocks();
    jest
      .spyOn(Date, 'now')
      .mockReturnValue(
        Date.parse(new X509Certificate(certificado).validFrom) + 60000,
      );
    model.configuracionQz.mockResolvedValue({
      certificado,
      clave_privada: clave,
      actualizado: new Date(),
    });
    model.impresoraActiva.mockResolvedValue(true);
  });
  afterEach(() => jest.restoreAllMocks());
  it('guarda el par y devuelve sólo metadatos', async () => {
    const result = await service.guardarConfiguracion(certificado, clave);
    expect(model.guardarConfiguracionQz).toHaveBeenCalledWith(
      certificado.trim(),
      clave.trim(),
    );
    expect(result.configurado).toBe(true);
    expect(JSON.stringify(result)).not.toContain('PRIVATE KEY');
    expect(result).not.toHaveProperty('clave_privada');
  });
  it('rechaza una clave que no corresponde y conserva la configuración anterior', async () => {
    const otra = generateKeyPairSync('rsa', { modulusLength: 2048 })
      .privateKey.export({ format: 'pem', type: 'pkcs8' })
      .toString();
    await expect(
      service.guardarConfiguracion(certificado, otra),
    ).rejects.toThrow('correspondiente');
    expect(model.guardarConfiguracionQz).not.toHaveBeenCalled();
  });
  it('rechaza certificado vencido y contenido inválido', async () => {
    jest
      .spyOn(Date, 'now')
      .mockReturnValue(
        Date.parse(new X509Certificate(certificado).validTo) + 1,
      );
    await expect(
      service.guardarConfiguracion(certificado, clave),
    ).rejects.toThrow('vigente');
    await expect(
      service.guardarConfiguracion('incorrecto', clave),
    ).rejects.toThrow('vigente');
    expect(model.guardarConfiguracionQz).not.toHaveBeenCalled();
  });
  it('firma desde la base sin rutas de archivos y sirve sólo el certificado público', async () => {
    const mensaje = JSON.stringify({
      call: 'socket.open',
      params: { host: '192.168.1.2', port: 9100 },
      timestamp: Date.now(),
    });
    const { firma } = await service.firmar(mensaje);
    expect(
      verify(
        'RSA-SHA512',
        Buffer.from(createHash('sha256').update(mensaje).digest('hex')),
        new X509Certificate(certificado).publicKey,
        Buffer.from(firma, 'base64'),
      ),
    ).toBe(true);
    expect(await service.certificado()).toEqual({ certificado });
  });
});
