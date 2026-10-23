import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Socket } from 'socket.io';
import { JwtStrategy } from '../../src/common/strategies/jwt.strategy';
import { canalesPermitidos } from '../../src/modules/notificaciones/constants/canales';
import { NotificacionesGateway } from '../../src/modules/notificaciones/gateways/notificaciones.gateway';
import { NotificacionesLogic } from '../../src/modules/notificaciones/logic/notificaciones.logic';
import { NotificacionesModel } from '../../src/modules/notificaciones/models/notificaciones.model';

type SocketFalso = {
  handshake: { auth: { token?: string } };
  connected: boolean;
  on: jest.Mock;
  emit: jest.Mock;
  disconnect: jest.Mock;
};

function socketFalso(token?: string): SocketFalso {
  return {
    handshake: { auth: { token } },
    connected: true,
    on: jest.fn(),
    emit: jest.fn(),
    disconnect: jest.fn(),
  };
}

const notif = (canal: string) => ({
  id: 'n1',
  canal,
  titulo: 'Stock bajo',
  mensaje: 'Quedan 2 kg',
  severidad: 'warning',
  ruta: '/productos/stock',
  idReferencia: 1,
  creadaEn: new Date(0).toISOString(),
  leida: false,
});

describe('Canales de notificaciones', () => {
  it('asigna los canales según los permisos reales', () => {
    const canales = canalesPermitidos({
      es_super_admin: false,
      permisos: ['pedidos.ver', 'inventario.ver', 'planilla.pagos.listar'],
    });
    expect(canales).toEqual(
      expect.arrayContaining(['pedidos', 'inventario', 'planilla', 'sistema']),
    );
    expect(canales).not.toContain('caja');
    expect(canales).not.toContain('ventas');
  });

  it('el super administrador recibe todos y se ignoran canales desconocidos', () => {
    const canales = canalesPermitidos({ es_super_admin: true, permisos: [] }, [
      'caja',
      'inexistente',
      'toString',
    ]);
    expect(canales).toEqual(['caja']);
  });
});

describe('NotificacionesGateway', () => {
  const jwt = { verifyAsync: jest.fn() };
  const auth = { validate: jest.fn() };
  let gateway: NotificacionesGateway;

  beforeEach(() => {
    jest.resetAllMocks();
    jwt.verifyAsync.mockResolvedValue({ sub: 1 });
    gateway = new NotificacionesGateway(
      jwt as unknown as JwtService,
      auth as unknown as JwtStrategy,
    );
  });

  async function conectar(id: number, permisos: string[]) {
    auth.validate.mockResolvedValueOnce({
      id,
      es_super_admin: false,
      permisos,
    });
    const s = socketFalso('token');
    await gateway.handleConnection(s as unknown as Socket);
    return s;
  }

  it('rechaza la conexión sin token', async () => {
    const s = socketFalso();
    await gateway.handleConnection(s as unknown as Socket);
    expect(s.disconnect).toHaveBeenCalledWith(true);
  });

  it('sin suscripción explícita el cliente recibe todos sus canales permitidos', async () => {
    const almacen = await conectar(1, ['inventario.ver']);
    const mozo = await conectar(2, ['pedidos.ver']);
    gateway.emitirNotificacion(notif('inventario'));
    expect(almacen.emit).toHaveBeenCalledWith(
      'notificacion:nueva',
      expect.objectContaining({ canal: 'inventario' }),
    );
    expect(mozo.emit).not.toHaveBeenCalledWith(
      'notificacion:nueva',
      expect.anything(),
    );
  });

  it('una notificación dirigida solo llega a sus destinatarios', async () => {
    const a = await conectar(1, ['inventario.ver']);
    const b = await conectar(2, ['inventario.ver']);
    gateway.emitirNotificacion(notif('inventario'), [2]);
    expect(a.emit).not.toHaveBeenCalledWith(
      'notificacion:nueva',
      expect.anything(),
    );
    expect(b.emit).toHaveBeenCalledWith(
      'notificacion:nueva',
      expect.anything(),
    );
  });

  it('la suscripción no permite ampliar canales sin permiso', async () => {
    auth.validate.mockResolvedValueOnce({
      id: 1,
      es_super_admin: false,
      permisos: ['pedidos.ver'],
    });
    const s = socketFalso('token');
    await gateway.handleConnection(s as unknown as Socket);
    const calls = s.on.mock.calls as [
      string,
      (d: unknown, a: unknown) => void,
    ][];
    const suscribir = calls.find(([e]) => e === 'notificaciones:suscribir')![1];
    const ack = jest.fn();
    suscribir({ canales: ['caja', 'pedidos'] }, ack);
    expect(ack).toHaveBeenCalledWith({ ok: true, canales: ['pedidos'] });
    gateway.emitirNotificacion(notif('caja'));
    expect(s.emit).not.toHaveBeenCalledWith(
      'notificacion:nueva',
      expect.anything(),
    );
  });

  it('avisa la lectura solo a las pestañas del mismo usuario', async () => {
    const a = await conectar(1, []);
    const b = await conectar(2, []);
    gateway.notificarLeidas(1, 'todas');
    expect(a.emit).toHaveBeenCalledWith('notificacion:leidas', {
      ids: 'todas',
    });
    expect(b.emit).not.toHaveBeenCalledWith(
      'notificacion:leidas',
      expect.anything(),
    );
  });
});

describe('NotificacionesLogic', () => {
  const model = {
    crear: jest.fn(),
    pendientesEmitir: jest.fn(),
    marcarTodasLeidas: jest.fn(),
  };
  const gateway = { emitirNotificacion: jest.fn(), notificarLeidas: jest.fn() };
  const config = { get: jest.fn() };
  let logic: NotificacionesLogic;

  beforeEach(() => {
    jest.resetAllMocks();
    logic = new NotificacionesLogic(
      model as unknown as NotificacionesModel,
      gateway as unknown as NotificacionesGateway,
      config as unknown as ConfigService,
    );
  });

  it('el despachador envía los pendientes generados en SQL respetando destinatarios', async () => {
    model.pendientesEmitir.mockResolvedValue({
      registros: [
        {
          id: 'a',
          canal: 'inventario',
          titulo: 't',
          mensaje: 'm',
          severidad: 'warning',
          ruta: '/productos/stock',
          id_referencia: '5',
          creada_en: '2026-10-22T10:00:00Z',
          ids_usuario_destino: null,
        },
        {
          id: 'b',
          canal: 'sistema',
          titulo: 't',
          mensaje: 'm',
          severidad: 'info',
          ruta: '/dashboard',
          id_referencia: null,
          creada_en: '2026-10-22T10:00:00Z',
          ids_usuario_destino: ['3'],
        },
      ],
    });
    await logic.despachar();
    expect(gateway.emitirNotificacion).toHaveBeenCalledWith(
      expect.objectContaining({ id: 'a', idReferencia: 5, leida: false }),
      undefined,
    );
    expect(gateway.emitirNotificacion).toHaveBeenCalledWith(
      expect.objectContaining({ id: 'b' }),
      [3],
    );
  });

  it('no emite si la notificación no se creó (clave repetida)', async () => {
    model.crear.mockResolvedValue({ id: null });
    const r = await logic.emitir({
      canal: 'caja',
      titulo: 't',
      mensaje: 'm',
      ruta: '/caja/turnos',
    });
    expect(r).toBeNull();
    expect(gateway.emitirNotificacion).not.toHaveBeenCalled();
  });

  it('solo un super administrador crea notificaciones manuales', () => {
    expect(() =>
      logic.crearManual(
        { canal: 'sistema', titulo: 't', mensaje: 'm', ruta: '/dashboard' },
        { es_super_admin: false } as never,
      ),
    ).toThrow('super administrador');
  });

  it('marcar todas usa los canales del usuario y sincroniza sus pestañas', async () => {
    model.marcarTodasLeidas.mockResolvedValue({ ok: true, total: 3 });
    await logic.marcarTodasLeidas(
      { id: 9, es_super_admin: false, permisos: ['ventas.listar'] } as never,
      {},
    );
    expect(model.marcarTodasLeidas).toHaveBeenCalledWith(
      9,
      expect.arrayContaining(['ventas', 'sistema']),
      undefined,
    );
    expect(gateway.notificarLeidas).toHaveBeenCalledWith(9, 'todas');
  });
});
