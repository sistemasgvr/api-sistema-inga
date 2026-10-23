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
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { AuthenticatedUser } from '../../../common/interfaces/authenticated-user.interface';
import { AuthSingleResult } from '../../../common/interfaces/auth-db.interface';
import { FiltroPedidoDto } from '../dto/pedido.dto';
import { AccionPedido, PedidoModel } from '../models/pedido.model';
import { ImpresionGateway } from '../../impresion/gateways/impresion.gateway';
import { NotificacionesLogic } from '../../notificaciones/logic/notificaciones.logic';
import { CrearNotificacionDto } from '../../notificaciones/dto/crear-notificacion.dto';
import { RutasNotificacion } from '../../notificaciones/constants/rutas-notificacion';
import { TicketPdfLogic } from '../../impresion/logic/ticket-pdf.logic';

// SQLSTATE de ven_reservar_insumos_pedido: faltan insumos o productos para comandar.
const STOCK_INSUFICIENTE = 'IN001';

@Injectable()
export class PedidoLogic {
  private readonly logger = new Logger(PedidoLogic.name);
  constructor(
    private readonly model: PedidoModel,
    private readonly config: ConfigService,
    private readonly impresion: ImpresionGateway,
    private readonly notificaciones: NotificacionesLogic,
    private readonly tickets: TicketPdfLogic,
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
    // Pasar a 4 cierra el pedido ya pagado, así que es parte del cobro.
    const permiso =
      accion !== 'estado'
        ? null
        : payload.estado_pedido === 2
          ? PermisoBanderas.PEDIDOS_COMANDAR
          : payload.estado_pedido === 4
            ? PermisoBanderas.PEDIDOS_COBRAR
            : payload.estado_pedido === 5
              ? PermisoBanderas.PEDIDOS_ANULAR
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
      const pedidoId = (id ?? (result as { id?: number } | null)?.id) as
        number | null;
      const comandado =
        accion === 'comandar' ||
        (accion === 'estado' && payload.estado_pedido === 2);
      const cobrado =
        accion === 'cobrar' ||
        (accion === 'estado' && payload.estado_pedido === 4);
      const anulado =
        accion === 'anular' ||
        (accion === 'estado' && payload.estado_pedido === 5);
      if (comandado || accion === 'precuenta') this.impresion.notificar();
      // El comprobante emitido se archiva en PDF (Storage) sin demorar la respuesta del cobro.
      if (cobrado && pedidoId) this.tickets.archivarComprobantes(pedidoId);
      if (pedidoId)
        this.notificarPedido(
          accion,
          { comandado, cobrado, anulado },
          pedidoId,
          result,
        );
      // Entregar descuenta stock: la alerta de mínimo, si la hay, sale al instante.
      if (accion === 'entregar') void this.notificaciones.despachar();
      return result;
    });
  }

  private notificarPedido(
    accion: AccionPedido,
    evento: { comandado: boolean; cobrado: boolean; anulado: boolean },
    pedidoId: number,
    result: unknown,
  ) {
    const pedido = result as {
      codigo?: string;
      codigo_mesa?: string | null;
    } | null;
    const nombre = pedido?.codigo ?? `#${pedidoId}`;
    const lugar = pedido?.codigo_mesa
      ? `Mesa ${pedido.codigo_mesa}`
      : 'Para llevar / delivery';
    let aviso: CrearNotificacionDto | null = null;
    if (evento.comandado)
      aviso = {
        canal: 'cocina',
        titulo: 'Nueva comanda',
        mensaje: `${lugar} · Pedido ${nombre}`,
        severidad: 'info',
        ruta: RutasNotificacion.cocina(pedidoId),
      };
    else if (accion === 'precuenta')
      aviso = {
        canal: 'pedidos',
        titulo: 'Precuenta solicitada',
        mensaje: `${lugar} · Pedido ${nombre}`,
        severidad: 'info',
        ruta: RutasNotificacion.pedido(pedidoId),
      };
    else if (evento.cobrado || accion === 'credito')
      aviso = {
        canal: 'ventas',
        titulo: evento.cobrado
          ? 'Pedido cobrado'
          : 'Pedido registrado a crédito',
        mensaje: `${lugar} · Pedido ${nombre}`,
        severidad: 'success',
        ruta: RutasNotificacion.venta(pedidoId),
      };
    else if (evento.anulado)
      aviso = {
        canal: 'pedidos',
        titulo: 'Pedido anulado',
        mensaje: `${lugar} · Pedido ${nombre}`,
        severidad: 'warning',
        ruta: RutasNotificacion.pedido(pedidoId),
      };
    else if (accion === 'anular_item')
      aviso = {
        canal: 'pedidos',
        titulo: 'Producto anulado en un pedido',
        mensaje: `${lugar} · Pedido ${nombre}`,
        severidad: 'warning',
        ruta: RutasNotificacion.pedido(pedidoId),
      };
    if (!aviso) return;
    this.notificaciones
      .emitir({ ...aviso, idReferencia: pedidoId })
      ?.catch((error: unknown) =>
        this.logger.warn(
          `No se notificó el pedido ${pedidoId}: ${String(error)}`,
        ),
      );
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
      this.notificaciones
        .emitir({
          canal: 'cocina',
          titulo: 'Stock insuficiente para comandar',
          mensaje: db.message ?? 'Stock insuficiente para comandar',
          severidad: 'warning',
          ruta: RutasNotificacion.cocina(pedido),
          idReferencia: pedido,
        })
        ?.catch(() => undefined);
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
