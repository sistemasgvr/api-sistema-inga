import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { LoginLogic } from './login.logic';
import { LoginModel } from '../models/login.model';

describe('LoginLogic.login', () => {
  const exp = 1_900_000_000;

  function crear() {
    const loginModel = {
      obtenerUsuarioPorLogin: jest.fn().mockResolvedValue({
        registro: {
          id: 1,
          email: 'a@b.pe',
          username: 'a',
          password_hash: bcrypt.hashSync('123456', 4),
        },
      }),
      crearSesion: jest
        .fn()
        .mockResolvedValue({ id_sesion: 9, id_sucursal_activa: 2 }),
      obtenerPermisosUsuario: jest.fn().mockResolvedValue({ permisos: [] }),
    };
    const jwtService = {
      signAsync: jest.fn().mockResolvedValue('token'),
      decode: jest.fn().mockReturnValue({ exp }),
    };
    const config = { get: jest.fn().mockReturnValue('30d') };
    const logic = new LoginLogic(
      loginModel as unknown as LoginModel,
      jwtService as unknown as JwtService,
      config as unknown as ConfigService,
    );
    return { logic, loginModel, jwtService };
  }

  it('con Recordarme firma el token con la duración larga', async () => {
    const { logic, jwtService } = crear();
    await logic.login({
      email: 'a@b.pe',
      password: '123456',
      rememberMe: true,
    });
    expect(jwtService.signAsync).toHaveBeenCalledWith(expect.anything(), {
      expiresIn: '30d',
    });
  });

  it('sin Recordarme usa la duración por defecto del módulo', async () => {
    const { logic, jwtService } = crear();
    await logic.login({ email: 'a@b.pe', password: '123456' });
    expect(jwtService.signAsync).toHaveBeenCalledWith(
      expect.anything(),
      undefined,
    );
  });

  it('la sesión en base de datos vence junto con el token', async () => {
    const { logic, loginModel } = crear();
    await logic.login({
      email: 'a@b.pe',
      password: '123456',
      rememberMe: true,
    });
    expect(loginModel.crearSesion).toHaveBeenCalledWith(
      1,
      'token',
      null,
      null,
      new Date(exp * 1000).toISOString(),
    );
  });
});
