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
import { PERMISOS_KEY, PERMISOS_ALGUNO_KEY } from '../decorators/permisos.decorator';
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

    const anyRequired = this.reflector.getAllAndOverride<PermisoBandera[]>(PERMISOS_ALGUNO_KEY, [context.getHandler(), context.getClass()]);
    if (!required?.length && !anyRequired?.length) {
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

    // Sin códigos técnicos (roles.listar...): el mensaje llega tal cual a la pantalla.
    const sinPermiso = 'No tienes permiso para realizar esta acción.';

    if (!user.permisos) {
      throw new ForbiddenException(sinPermiso);
    }

    if (anyRequired?.length && !anyRequired.some(permission => user.permisos.includes(permission))) {
      throw new ForbiddenException(sinPermiso);
    }
    const faltantes = (required ?? []).filter((p) => !user.permisos.includes(p));

    if (faltantes.length > 0) {
      throw new ForbiddenException(sinPermiso);
    }

    return true;
  }
}
