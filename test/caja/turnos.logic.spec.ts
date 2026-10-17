import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { TurnosModel } from '../../src/modules/turnos/models/turnos.model';
import { NotificacionesLogic } from '../../src/modules/notificaciones/logic/notificaciones.logic';
import {
  esAdministrador,
  TurnosLogic,
} from '../../src/modules/turnos/logic/turnos.logic';

describe('Cierre de caja: quién puede cerrarla', () => {
  const model = {
    obtenerPorId: jest.fn(),
    obtenerUsuario: jest.fn(),
    cerrar: jest.fn(),
    guardarArqueo: jest.fn(),
  };
  const notificaciones = { emitir: jest.fn().mockResolvedValue(undefined) };
  const logic = new TurnosLogic(model as unknown as TurnosModel, notificaciones as unknown as NotificacionesLogic);

  const turnoAbierto = {
    id: 10,
    id_cajero: 3,
    nombre_cajero: 'Ana Cajera',
    estado_turno: 1,
  };
  const cierre = { monto_cierre_declarado: 100 };

  beforeEach(() => {
    jest.resetAllMocks();
    model.obtenerPorId.mockResolvedValue({ registro: turnoAbierto });
    model.cerrar.mockResolvedValue({
      registro: { ...turnoAbierto, estado_turno: 2 },
    });
    model.guardarArqueo.mockResolvedValue({
      registro: { turno: turnoAbierto },
    });
  });

  it('el cajero que abrió la caja la cierra sin consultar sus roles', async () => {
    await expect(
      logic.cerrar(10, { ...cierre, idUsuarioAuditoria: 3 }),
    ).resolves.toMatchObject({ estado_turno: 2 });
    expect(model.obtenerUsuario).not.toHaveBeenCalled();
    expect(model.cerrar).toHaveBeenCalledWith(10, {
      ...cierre,
      idUsuarioAuditoria: 3,
    });
  });

  it('un administrador cierra la caja aunque no sea su turno', async () => {
    model.obtenerUsuario.mockResolvedValue({
      registro: { es_super_admin: false, roles: [{ codigo: 'ADMIN' }] },
    });
    await expect(
      logic.cerrar(10, { ...cierre, idUsuarioAuditoria: 7 }),
    ).resolves.toMatchObject({ estado_turno: 2 });
    expect(model.obtenerUsuario).toHaveBeenCalledWith(7);
  });

  it('el superadministrador también puede cerrarla', async () => {
    model.obtenerUsuario.mockResolvedValue({
      registro: { es_super_admin: true, roles: [] },
    });
    await expect(
      logic.cerrar(10, { ...cierre, idUsuarioAuditoria: 1 }),
    ).resolves.toBeDefined();
  });

  it('responde 403 con un mensaje claro a cualquier otro usuario', async () => {
    model.obtenerUsuario.mockResolvedValue({
      registro: { es_super_admin: false, roles: [{ codigo: 'CAJERO' }] },
    });
    const intento = logic.cerrar(10, { ...cierre, idUsuarioAuditoria: 8 });
    await expect(intento).rejects.toBeInstanceOf(ForbiddenException);
    await expect(intento).rejects.toThrow(
      'Solo Ana Cajera, quien abrió esta caja, o un administrador puede cerrarla.',
    );
    expect(model.cerrar).not.toHaveBeenCalled();
  });

  it('sin usuario autenticado no cierra', async () => {
    await expect(logic.cerrar(10, cierre)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    expect(model.cerrar).not.toHaveBeenCalled();
  });

  it('el arqueo de una caja ajena sigue la misma regla', async () => {
    model.obtenerUsuario.mockResolvedValue({
      registro: { es_super_admin: false, roles: [{ codigo: 'MOZO' }] },
    });
    await expect(
      logic.guardarArqueo(10, {
        detalle: [{ denominacion: 10, cantidad: 2 }],
        idUsuarioAuditoria: 8,
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(model.guardarArqueo).not.toHaveBeenCalled();
  });

  it('un turno inexistente responde 404 antes de cerrar', async () => {
    model.obtenerPorId.mockResolvedValue({ registro: null });
    await expect(
      logic.cerrar(99, { ...cierre, idUsuarioAuditoria: 3 }),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(model.cerrar).not.toHaveBeenCalled();
  });

  it('un turno ya cerrado deja el mensaje a la función SQL', async () => {
    model.obtenerPorId.mockResolvedValue({
      registro: { ...turnoAbierto, estado_turno: 2 },
    });
    model.cerrar.mockResolvedValue({
      error: 'Este turno ya fue cerrado',
      registro: null,
    });
    await expect(
      logic.cerrar(10, { ...cierre, idUsuarioAuditoria: 8 }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(model.obtenerUsuario).not.toHaveBeenCalled();
  });
});

describe('esAdministrador', () => {
  it('reconoce el rol ADMIN y al superadministrador', () => {
    expect(esAdministrador({ roles: [{ codigo: 'ADMIN' }] })).toBe(true);
    expect(esAdministrador({ es_super_admin: true })).toBe(true);
  });

  it('no trata como administrador a otros roles ni a un usuario vacío', () => {
    expect(esAdministrador({ roles: [{ codigo: 'OPERARIO' }] })).toBe(false);
    expect(esAdministrador({ roles: null })).toBe(false);
    expect(esAdministrador(null)).toBe(false);
  });
});
