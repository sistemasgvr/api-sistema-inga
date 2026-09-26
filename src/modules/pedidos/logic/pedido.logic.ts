import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { mapSingleResult } from '../../../common/helpers/auth-response.helper';
import { AuthenticatedUser } from '../../../common/interfaces/authenticated-user.interface';
import { AuthSingleResult } from '../../../common/interfaces/auth-db.interface';
import { AccionPedido, PedidoModel } from '../models/pedido.model';

@Injectable()
export class PedidoLogic {
  constructor(
    private readonly model: PedidoModel,
    private readonly config: ConfigService,
  ) {}

  obtener(id: number) {
    return this.resolver(() => this.model.obtener(id));
  }

  ejecutar(
    accion: AccionPedido,
    id: number | null,
    item: number | null,
    datos: object,
    usuario: AuthenticatedUser,
  ) {
    const payload = { ...datos } as Record<string, unknown>;
    if (accion === 'abrir')
      payload.tasa_igv = this.config.get<number>('PEDIDOS_TASA_IGV', 18);
    // Cambiar estado no permite saltarse los permisos de las operaciones que producen efectos.
    const permiso =
      accion === 'estado' && payload.estado_pedido === 2
        ? 'pedidos.comandar'
        : accion === 'estado' && payload.estado_pedido === 5
          ? 'pedidos.anular'
          : null;
    if (
      permiso &&
      !usuario.es_super_admin &&
      !usuario.permisos.includes(permiso)
    ) {
      throw new ForbiddenException(`Se requiere el permiso ${permiso}`);
    }
    return this.resolver(() =>
      this.model.ejecutar(accion, id, item, payload, usuario.id),
    );
  }

  private async resolver(operacion: () => Promise<AuthSingleResult>) {
    try {
      return mapSingleResult(await operacion(), 'Pedido no encontrado');
    } catch (error: unknown) {
      const db = error as { code?: string; message?: string };
      if (db.code === 'P0002') throw new NotFoundException(db.message);
      if (db.code === '42501') throw new ForbiddenException(db.message);
      if (db.code === 'P0001') throw new BadRequestException(db.message);
      if (['23505', '40001', '40P01'].includes(db.code ?? ''))
        throw new ConflictException(
          'La operación entró en conflicto con otro cambio. Consulta el pedido y vuelve a intentar.',
        );
      if (['23503', '23514', '23502', '22003', '22P02'].includes(db.code ?? ''))
        throw new BadRequestException(
          'Los datos no cumplen las restricciones del pedido.',
        );
      throw error;
    }
  }
}
