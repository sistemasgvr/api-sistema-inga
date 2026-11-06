import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService, JwtSignOptions } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { randomUUID } from 'crypto';
import { AuthCloseResult } from '../../../common/interfaces/auth-db.interface';
import type { AuthenticatedUser } from '../../../common/interfaces/authenticated-user.interface';
import { mapSingleResult } from '../../../common/helpers/auth-response.helper';
import { LoginDto } from '../dto/login.dto';
import { LoginModel } from '../models/login.model';

@Injectable()
export class LoginLogic {
  constructor(
    private readonly loginModel: LoginModel,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  async login(dto: LoginDto) {
    const result = await this.loginModel.obtenerUsuarioPorLogin(dto.email);
    const usuario = result.registro;

    if (!usuario) {
      throw new UnauthorizedException('Credenciales inválidas');
    }

    const passwordValida = await bcrypt.compare(
      dto.password,
      usuario.password_hash,
    );

    if (!passwordValida) {
      throw new UnauthorizedException('Credenciales inválidas');
    }

    const token = await this.jwtService.signAsync(
      {
        sub: usuario.id,
        email: usuario.email,
        username: usuario.username,
        jti: randomUUID(),
      },
      dto.rememberMe
        ? {
            expiresIn: this.configService.get<string>(
              'jwt.rememberExpiresIn',
            ) as JwtSignOptions['expiresIn'],
          }
        : undefined,
    );

    // La sesión en BD vence junto con el token; si no, cortaría antes a "Recordarme".
    const { exp } = this.jwtService.decode<{ exp: number }>(token);

    const sesionResult = await this.loginModel.crearSesion(
      usuario.id,
      token,
      dto.ip ?? null,
      dto.userAgent ?? null,
      new Date(exp * 1000).toISOString(),
    );

    const permisosResult = await this.loginModel.obtenerPermisosUsuario(
      usuario.id,
    );

    const { password_hash: _, pin_hash: __, ...usuarioSinClaves } = usuario;

    return {
      token,
      sesionId: sesionResult.id_sesion,
      usuario: {
        ...usuarioSinClaves,
        // Empresa y sucursales permitidas vienen en usuarioSinClaves; la activa, de la sesión.
        id_sucursal_activa: sesionResult.id_sucursal_activa ?? null,
        permisos: permisosResult.permisos ?? [],
      },
    };
  }

  /** Usuario de la sesión con sus sucursales permitidas (para refrescar el front). */
  async sesion(user: AuthenticatedUser) {
    return {
      ...user,
      sucursales: (await this.loginModel.sucursalesUsuario(user.id)) ?? [],
    };
  }

  /** Cambia la sucursal en la que trabaja la sesión actual. */
  async cambiarSucursal(user: AuthenticatedUser, idSucursal: number) {
    const sucursal = mapSingleResult(
      await this.loginModel.cambiarSucursal(
        user.sesion.id,
        user.id,
        idSucursal,
      ),
      'La sucursal no existe',
    );
    return { id_sucursal_activa: sucursal.id, sucursal };
  }

  async logout(idSesion: number, idUsuario: number): Promise<AuthCloseResult> {
    const result = await this.loginModel.cerrarSesion(idSesion, idUsuario);

    if (!result.cerrada) {
      throw new UnauthorizedException('No se pudo cerrar la sesión');
    }

    return result;
  }
}
