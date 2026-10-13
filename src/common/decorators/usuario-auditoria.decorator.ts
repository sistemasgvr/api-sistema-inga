import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import type { AuthenticatedUser } from '../interfaces/authenticated-user.interface';

// ID del usuario autenticado, sacado del token. La auditoría no se confía al
// body: el front no siempre lo manda y cualquiera podría poner otro ID.
export const UsuarioAuditoria = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): number => {
    const request = ctx.switchToHttp().getRequest<{ user: AuthenticatedUser }>();
    return request.user.id;
  },
);
