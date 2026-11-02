import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import {
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { FiltroVentasDto, ReemitirComprobanteDto } from '../dto/ventas.dto';

@Injectable()
export class VentasModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroVentasDto, idEmpresa: number | null) {
    return this.db.callFunctionJson<AuthListResult>('ven_listar_ventas', [
      JSON.stringify({
        ...filtros,
        offset: filtros.offset,
        id_empresa: idEmpresa,
      }),
    ]);
  }

  obtener(id: number, idEmpresa: number | null) {
    return this.db.callFunctionJson<AuthSingleResult>('ven_obtener_venta', [
      id,
      idEmpresa,
    ]);
  }

  cambiarMedioPago(
    idPago: number,
    medio: number,
    usuario: number,
    idEmpresa: number | null,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'ven_cambiar_medio_pago',
      [idPago, medio, usuario, idEmpresa],
    );
  }

  reemitirComprobante(
    idPedido: number,
    dto: ReemitirComprobanteDto,
    usuario: number,
    idEmpresa: number | null,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'ven_reemitir_comprobante',
      [idPedido, JSON.stringify(dto), usuario, idEmpresa],
    );
  }

  reimprimirComanda(
    idComanda: number,
    usuario: number,
    idEmpresa: number | null,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'ven_reimprimir_comanda',
      [idComanda, usuario, idEmpresa],
    );
  }

  imprimirComprobante(
    idComprobante: number,
    usuario: number,
    idEmpresa: number | null,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'ven_imprimir_comprobante',
      [idComprobante, usuario, idEmpresa],
    );
  }
}
