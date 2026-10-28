import { ConfigService } from '@nestjs/config';
import axios, { type AxiosInstance } from 'axios';
import {
  ApisPeruFallo,
  ApisPeruService,
} from '../../src/integrations/apisperu/apisperu.service';

describe('Cliente APIsPERU', () => {
  const http = {
    post: jest.fn(() => Promise.resolve({ data: { ok: true } })),
    get: jest.fn(() => Promise.resolve({ data: { code: '98' } })),
  };
  const crear = jest.spyOn(axios, 'create');

  beforeEach(() => {
    jest.clearAllMocks();
    crear.mockReturnValue(http as unknown as AxiosInstance);
  });

  it('usa la URL base del .env y la ruta de cada operación', async () => {
    const servicio = new ApisPeruService(
      new ConfigService({
        APISPERU_URL: 'https://apisperu.test/api/v1/',
        APISPERU_TIMEOUT_MS: 5000,
      }),
    );
    expect(crear).toHaveBeenCalledWith({
      baseURL: 'https://apisperu.test/api/v1',
      timeout: 5000,
    });
    await servicio.enviarFactura('tk', { a: 1 });
    await servicio.estadoResumen('tk', '123');
    expect(http.post).toHaveBeenCalledWith(
      'invoice/send',
      { a: 1 },
      { headers: { Authorization: 'Bearer tk' }, responseType: 'json' },
    );
    expect(http.get).toHaveBeenCalledWith('summary/status', {
      headers: { Authorization: 'Bearer tk' },
      params: { ticket: '123' },
    });
  });

  it('sin APISPERU_URL avisa y no llama a APIsPERU', async () => {
    const servicio = new ApisPeruService(new ConfigService({}));
    await expect(servicio.enviarFactura('tk', {})).rejects.toBeInstanceOf(
      ApisPeruFallo,
    );
    await expect(servicio.enviarBaja('tk', {})).rejects.toThrow(/APISPERU_URL/);
    expect(http.post).not.toHaveBeenCalled();
  });
});
