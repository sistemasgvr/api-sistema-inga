import { JwtService } from '@nestjs/jwt';
import { Socket } from 'socket.io';
import { JwtStrategy } from '../../src/common/strategies/jwt.strategy';
import { ImpresionGateway } from '../../src/modules/impresion/gateways/impresion.gateway';
import { ImpresionLogic } from '../../src/modules/impresion/logic/impresion.logic';

describe('Autenticación del receptor WebSocket', () => {
  const jwt = { verifyAsync: jest.fn() };
  const auth = { validate: jest.fn() };
  const service = { tomar: jest.fn() };
  let handlers: Record<
    string,
    (data: unknown, ack: (data: unknown) => void) => void
  >;
  let socket: {
    handshake: { auth: { token: string } };
    connected: boolean;
    on: jest.Mock;
    emit: jest.Mock;
    disconnect: jest.Mock;
  };
  let gateway: ImpresionGateway;
  beforeEach(() => {
    jest.resetAllMocks();
    handlers = {};
    jwt.verifyAsync.mockResolvedValue({ sub: 7 });
    auth.validate.mockResolvedValue({
      es_super_admin: false,
      permisos: ['estaciones.listar', 'pedidos.comandar'],
    });
    service.tomar.mockResolvedValue(null);
    socket = {
      handshake: { auth: { token: 'token' } },
      connected: true,
      on: jest.fn(
        (
          event: string,
          handler: (data: unknown, ack: (data: unknown) => void) => void,
        ) => {
          handlers[event] = handler;
        },
      ),
      emit: jest.fn(),
      disconnect: jest.fn(),
    };
    gateway = new ImpresionGateway(
      jwt as unknown as JwtService,
      auth as unknown as JwtStrategy,
      service as unknown as ImpresionLogic,
    );
  });
  it('rechaza JWT inválido antes de entregar trabajos', async () => {
    jwt.verifyAsync.mockRejectedValue(new Error('expired'));
    await gateway.handleConnection(socket as unknown as Socket);
    expect(socket.disconnect).toHaveBeenCalledWith(true);
    expect(service.tomar).not.toHaveBeenCalled();
  });
  it('rechaza usuarios sin permiso para comandar', async () => {
    auth.validate.mockResolvedValue({
      es_super_admin: false,
      permisos: ['estaciones.listar'],
    });
    await gateway.handleConnection(socket as unknown as Socket);
    expect(socket.disconnect).toHaveBeenCalledWith(true);
  });
  it('revalida la sesión en cada solicitud y no entrega después del logout', async () => {
    await gateway.handleConnection(socket as unknown as Socket);
    auth.validate.mockRejectedValue(new Error('Sesión cerrada'));
    const result = await new Promise((resolve) =>
      handlers['impresion:solicitar']({ estaciones: [1] }, resolve),
    );
    expect(result).toMatchObject({ ok: false });
    expect(service.tomar).not.toHaveBeenCalled();
  });
  it('asigna propietario generado en servidor y limita las estaciones', async () => {
    await gateway.handleConnection(socket as unknown as Socket);
    const result = await new Promise((resolve) =>
      handlers['impresion:solicitar']({ estaciones: [1, 2] }, resolve),
    );
    expect(result).toMatchObject({
      ok: true,
      trabajo: null,
    });
    expect(service.tomar).toHaveBeenCalledWith(
      [1, 2],
      expect.stringMatching(/^[0-9a-f-]{36}$/),
    );
  });
});
