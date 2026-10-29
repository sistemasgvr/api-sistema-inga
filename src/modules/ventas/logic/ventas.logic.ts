import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { AuthSingleResult } from '../../../common/interfaces/auth-db.interface';
import { ImpresionGateway } from '../../impresion/gateways/impresion.gateway';
import { TicketPdfLogic } from '../../impresion/logic/ticket-pdf.logic';
import { SunatLotesLogic } from '../../sunat/logic/sunat-lotes.logic';
import { FiltroVentasDto, ReemitirComprobanteDto } from '../dto/ventas.dto';
import { VentasModel } from '../models/ventas.model';

@Injectable()
export class VentasLogic {
  constructor(
    private readonly model: VentasModel,
    private readonly impresion: ImpresionGateway,
    private readonly tickets: TicketPdfLogic,
    private readonly sunat: SunatLotesLogic,
  ) {}

  async listar(filtros: FiltroVentasDto) {
    return mapListResult(await this.model.listar(filtros), filtros);
  }

  obtener(id: number) {
    return this.resolver(() => this.model.obtener(id));
  }

  async cambiarMedioPago(
    idPago: number,
    medio: number,
    usuario: number,
    idEmpresa: number | null,
  ) {
    const venta = await this.resolver(() =>
      this.model.cambiarMedioPago(idPago, medio, usuario),
    );
    // El comprobante archivado muestra los medios de pago: se vuelve a generar.
    const idPedido = (venta as { id?: number } | null)?.id;
    if (idPedido) {
      try {
        await this.tickets.regenerarComprobantes(idPedido, idEmpresa);
      } catch {
        // El cambio de pago ya se guardó; el PDF se regenera en la próxima consulta.
      }
    }
    return venta;
  }

  async reemitirComprobante(
    idPedido: number,
    dto: ReemitirComprobanteDto,
    usuario: number,
    idEmpresa: number | null,
  ) {
    const anterior = await this.sunat.comprobanteVigente(idPedido);
    const venta = await this.resolver(() =>
      this.model.reemitirComprobante(idPedido, dto, usuario, idEmpresa),
    );
    this.tickets.archivarComprobantes(idPedido, idEmpresa);
    // Si SUNAT ya había aceptado el comprobante reemplazado, se envía su baja.
    this.sunat.bajaPorReemision(anterior, usuario);
    return venta;
  }

  comandaPdf(idComanda: number) {
    return this.tickets.trabajo(idComanda);
  }

  comprobantePdf(idComprobante: number, idEmpresa: number | null) {
    return this.tickets.comprobante(idComprobante, idEmpresa);
  }

  async reimprimirComanda(idComanda: number, usuario: number) {
    const venta = await this.resolver(() =>
      this.model.reimprimirComanda(idComanda, usuario),
    );
    // Igual que al comandar: se avisa después de confirmar el trabajo en la base.
    this.impresion.notificar();
    return venta;
  }

  async imprimirComprobante(idComprobante: number, usuario: number) {
    const venta = await this.resolver(() =>
      this.model.imprimirComprobante(idComprobante, usuario),
    );
    this.impresion.notificar();
    return venta;
  }

  // Mismo criterio que PedidoLogic: los RAISE EXCEPTION del SQL son mensajes
  // para el usuario y se devuelven como 400/404 en vez de un 500.
  private async resolver(operacion: () => Promise<AuthSingleResult>) {
    try {
      return mapSingleResult(await operacion(), 'Venta no encontrada');
    } catch (error: unknown) {
      const db = error as { code?: string; message?: string };
      if (db.code === 'P0002') throw new NotFoundException(db.message);
      if (db.code === '42501') throw new ForbiddenException(db.message);
      if (db.code === 'P0001') throw new BadRequestException(db.message);
      if (['23505', '40001', '40P01'].includes(db.code ?? ''))
        throw new ConflictException(
          'La operación entró en conflicto con otro cambio. Vuelve a consultar la venta e intenta de nuevo.',
        );
      if (['23503', '23514', '23502', '22003', '22P02'].includes(db.code ?? ''))
        throw new BadRequestException(
          'Los datos no cumplen las restricciones de la venta.',
        );
      throw error;
    }
  }
}
