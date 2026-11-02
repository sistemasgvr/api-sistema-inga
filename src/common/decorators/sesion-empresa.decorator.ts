import {
  createParamDecorator,
  ExecutionContext,
  ForbiddenException,
} from '@nestjs/common';
import type { AuthenticatedUser } from '../interfaces/authenticated-user.interface';

const usuario = (ctx: ExecutionContext) =>
  ctx.switchToHttp().getRequest<{ user: AuthenticatedUser }>().user;

/** Sucursal activa de la sesión; sin ella no se opera lo diario de una sucursal. */
export function sucursalDe(user: AuthenticatedUser | undefined): number {
  if (!user?.id_sucursal)
    throw new ForbiddenException(
      'Seleccione la sucursal en la que trabaja para continuar',
    );
  return user.id_sucursal;
}

/** Empresa del usuario autenticado (la de su trabajador). */
export const EmpresaSesion = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): number | null =>
    usuario(ctx)?.id_empresa ?? null,
);

/** Sucursal en la que trabaja la sesión (obligatoria). */
export const SucursalSesion = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): number => sucursalDe(usuario(ctx)),
);
