import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { AuthenticatedUser } from '../../../common/interfaces/authenticated-user.interface';
import { AuthSingleResult } from '../../../common/interfaces/auth-db.interface';
import { FiltroPedidoDto } from '../dto/pedido.dto';
import { AccionPedido, PedidoModel } from '../models/pedido.model';
import { ImpresionGateway } from '../../impresion/gateways/impresion.gateway';

// SQLSTATE de ven_reservar_insumos_pedido: faltan insumos o productos para comandar.
const STOCK_INSUFICIENTE = 'IN001';

@Injectable()
export class PedidoLogic {
  private readonly logger = new Logger(PedidoLogic.name);
  constructor(
    private readonly model: PedidoModel,
    private readonly config: ConfigService,
    private readonly impresion: ImpresionGateway,
  ) {}

  async listar(filtros: FiltroPedidoDto) {
    return mapListResult(await this.model.listar(filtros), filtros);
  }

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
    return this.resolver(async () => {
      try {
        return await this.model.ejecutar(accion, id, item, payload, usuario.id);
      } catch (error: unknown) {
        // La comanda ya se revirtió; el aviso se guarda en una transacción aparte.
        const db = error as {
          code?: string;
          message?: string;
          detail?: string;
        };
        if (db.code === STOCK_INSUFICIENTE && id !== null)
          await this.avisarCocina(id, db, usuario.id);
        throw error;
      }
    }).then((result) => {
      if (
        accion === 'comandar' ||
        accion === 'precuenta' ||
        (accion === 'estado' && payload.estado_pedido === 2)
      ) {
        this.impresion.notificar();
      }
      return result;
    });
  }

  private async avisarCocina(
    pedido: number,
    db: { message?: string; detail?: string },
    usuario: number,
  ) {
    try {
      await this.model.registrarAvisoCocina(
        pedido,
        db.message ?? 'Stock insuficiente para comandar',
        db.detail ?? '[]',
        usuario,
      );
    } catch (error: unknown) {
      // No ocultar el rechazo de la comanda si el aviso no pudo guardarse.
      this.logger.error(
        `No se registró el aviso a cocina del pedido ${pedido}`,
        error as Error,
      );
    }
  }

  private async resolver(operacion: () => Promise<AuthSingleResult>) {
    try {
      return mapSingleResult(await operacion(), 'Pedido no encontrado');
    } catch (error: unknown) {
      const db = error as { code?: string; message?: string };
      if (db.code === STOCK_INSUFICIENTE)
        throw new ConflictException(`${db.message}. Se avisó a cocina.`);
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
