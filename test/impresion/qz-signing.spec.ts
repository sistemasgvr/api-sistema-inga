import { ImpresionModel } from '../../src/modules/impresion/models/impresion.model';
import { ConfigService } from '@nestjs/config';
import { createHash, generateKeyPairSync, verify } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { DatabaseService } from '../../src/database/database.service';
import { QzSigningLogic } from '../../src/modules/impresion/logic/qz-signing.logic';

jest.mock('node:fs/promises', () => ({ readFile: jest.fn() }));

describe('Firma QZ', () => {
  const db = { query: jest.fn() };
  const config = new ConfigService({
    NODE_ENV: 'production',
    QZ_PRIVATE_KEY_PATH: 'test-key.pem',
  });
  const service = new QzSigningLogic(
    config,
    new ImpresionModel(db as unknown as DatabaseService),
  );
  const mensaje = (
    call = 'socket.open',
    params: object = { host: '192.168.1.101', port: 9100 },
  ) => JSON.stringify({ call, params, timestamp: Date.now() });
  beforeEach(() => {
    jest.resetAllMocks();
    db.query.mockResolvedValue({ rowCount: 1 });
  });

  it('firma el hash SHA-256 con RSA-SHA512 como requiere QZ Tray', async () => {
    const { publicKey, privateKey } = generateKeyPairSync('rsa', {
      modulusLength: 2048,
    });
    jest
      .mocked(readFile)
      .mockResolvedValue(privateKey.export({ format: 'pem', type: 'pkcs8' }));
    const input = mensaje();
    const { firma } = await service.firmar(input);
    const digest = createHash('sha256').update(input).digest('hex');
    expect(
      verify(
        'RSA-SHA512',
        Buffer.from(digest),
        publicKey,
        Buffer.from(firma, 'base64'),
      ),
    ).toBe(true);
  });
  it.each(['file.read', 'socket.sendData', 'usb.sendData'])(
    'rechaza llamadas arbitrarias: %s',
    async (call) => {
      await expect(service.firmar(mensaje(call))).rejects.toThrow(
        'no permitida',
      );
      expect(readFile).not.toHaveBeenCalled();
    },
  );
  it('rechaza destinos que no estén registrados en estaciones activas', async () => {
    db.query.mockResolvedValue({ rowCount: 0 });
    await expect(service.firmar(mensaje())).rejects.toThrow('estación activa');
  });
  it('rechaza lectura de archivos mediante la API print', async () => {
    await expect(
      service.firmar(
        mensaje('print', {
          printer: { host: '192.168.1.101', port: 9100 },
          data: [
            { type: 'raw', format: 'command', flavor: 'file', data: '/secret' },
          ],
        }),
      ),
    ).rejects.toThrow('Sólo se permite');
  });
  it('no permite desactivar firmas en producción', async () => {
    const production = new QzSigningLogic(
      new ConfigService({ NODE_ENV: 'production', QZ_ALLOW_UNSIGNED: 'true' }),
      new ImpresionModel(db as unknown as DatabaseService),
    );
    await expect(production.certificado()).rejects.toThrow('Configura');
    await expect(production.firmar(mensaje())).rejects.toThrow('clave');
  });
  it('rechaza mensajes antiguos y JSON inválido', async () => {
    await expect(
      service.firmar(JSON.stringify({ call: 'socket.open', timestamp: 1 })),
    ).rejects.toThrow('expirado');
    await expect(service.firmar('{')).rejects.toThrow('inválido');
  });
});
