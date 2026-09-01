import {
  ExecutionContext,
  Injectable,
  UnauthorizedException,
  ForbiddenException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthGuard } from '@nestjs/passport';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';
import { PERMISOS_KEY } from '../decorators/permisos.decorator';
import type { PermisoBandera } from '../constants/permiso-banderas';
import type { AuthenticatedUser } from '../interfaces/authenticated-user.interface';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  constructor(private readonly reflector: Reflector) {
    super();
  }

  async canActivate(context: ExecutionContext): Promise<boolean> {
    if (context.getType() !== 'http') {
      return true;
    }

    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (isPublic) {
      return true;
    }

    const isValid = await super.canActivate(context);
    if (!isValid) {
      return false;
    }

    const required = this.reflector.getAllAndOverride<PermisoBandera[]>(
      PERMISOS_KEY,
      [context.getHandler(), context.getClass()],
    );

    if (!required?.length) {
      return true;
    }

    const request = context.switchToHttp().getRequest();
    const user = request.user as AuthenticatedUser | undefined;

    if (!user) {
      throw new ForbiddenException('Usuario no autenticado');
    }

    if (user.es_super_admin) {
      return true;
    }

    if (!user.permisos) {
      throw new ForbiddenException('No tiene permisos suficientes');
    }

    const faltantes = required.filter((p) => !user.permisos.includes(p));

    if (faltantes.length > 0) {
      throw new ForbiddenException(
        `Permisos requeridos: ${required.join(', ')}`,
      );
    }

    return true;
  }

  handleRequest(err: any, user: any, info: any, context: ExecutionContext) {
    if (err || !user) {
      throw err || new UnauthorizedException('Token no proporcionado o inválido');
    }
    return user;
  }
}