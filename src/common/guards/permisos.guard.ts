import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import {
  type PermisoBandera,
} from '../constants/permiso-banderas';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';
import { PERMISOS_KEY } from '../decorators/permisos.decorator';
import type { AuthenticatedUser } from '../interfaces/authenticated-user.interface';

@Injectable()
export class PermisosGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    console.log('--- ENTRANDO AL PERMISOS GUARD ---');
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

    const required = this.reflector.getAllAndOverride<PermisoBandera[]>(
      PERMISOS_KEY,
      [context.getHandler(), context.getClass()],
    );

    console.log('--- RUTA ---', context.switchToHttp().getRequest().url);
    console.log('--- PERMISOS REQUERIDOS ---', required);
    console.log('--- USUARIO EN REQUEST ---', context.switchToHttp().getRequest().user);

    if (!required?.length) {
      return true;
    }

    const user = context.switchToHttp().getRequest().user as
      | AuthenticatedUser
      | undefined;

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
}
