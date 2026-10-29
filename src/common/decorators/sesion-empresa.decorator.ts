import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import type { AuthenticatedUser } from '../interfaces/authenticated-user.interface';

const usuario = (ctx: ExecutionContext) =>
  ctx.switchToHttp().getRequest<{ user: AuthenticatedUser }>().user;

/** Empresa del usuario autenticado (la de su trabajador). */
export const EmpresaSesion = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): number | null =>
    usuario(ctx)?.id_empresa ?? null,
);

/** Sucursal en la que trabaja la sesión. */
export const SucursalSesion = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): number | null =>
    usuario(ctx)?.id_sucursal ?? null,
);
