import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { Request } from 'express';
import { Strategy } from 'passport-jwt';
import { DatabaseService } from '../../database/database.service';
import { AuthSessionValidateResult } from '../interfaces/auth-db.interface';

export interface JwtPayload {
  sub: number;
  correo: string;
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(
    configService: ConfigService,
    private readonly db: DatabaseService,
  ) {
    super({
      jwtFromRequest: (req: Request) => {
        const authHeader = req.headers.authorization ?? '';
        return authHeader.startsWith('Bearer ') ? authHeader.slice(7) : authHeader;
      },
      ignoreExpiration: false,
      secretOrKey: configService.getOrThrow<string>('jwt.secret'),
      passReqToCallback: true,
    });
  }

  async validate(req: Request, payload: JwtPayload) {
    const authHeader = req.headers.authorization ?? '';
    const token = authHeader.startsWith('Bearer ')
      ? authHeader.slice(7)
      : authHeader;

    const result = await this.db.callFunctionJson<AuthSessionValidateResult<{
      id: number;
      id_usuario: number;
      nombre_usuario: string;
      correo: string;
      nombres: string;
      apellidos: string;
      es_super_admin: boolean;
      estado: number;
      fecha_inicio: string;
    }>>('auth_validar_sesion', [token]);

    if (!result.valida || !result.registro) {
      throw new UnauthorizedException('Sesión inválida o expirada');
    }

    const permisosResult = await this.db.callFunctionJson<{ permisos: string[] }>(
      'auth_obtener_permisos_usuario',
      [payload.sub],
    );

    return {
      id: payload.sub,
      correo: payload.correo,
      username: result.registro.nombre_usuario,
      nombres: result.registro.nombres,
      apellidos: result.registro.apellidos,
      es_super_admin: result.registro.es_super_admin ?? false,
      permisos: permisosResult.permisos ?? [],
      sesion: result.registro,
    };
  }
}
