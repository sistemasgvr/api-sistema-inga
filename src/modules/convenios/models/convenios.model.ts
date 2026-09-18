import { Injectable } from '@nestjs/common';
import {
  AuthActivateResult,
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import { ConvenioEstadoFiltro, FiltroConveniosDto } from '../dto/convenios.dto';

/**
 * Capa que habla con la base. No decide nada: solo traduce los datos que le
 * pasan a los parámetros que espera cada función SQL, en el orden correcto.
 * Toda la regla de negocio vive en las funciones `cli_*_convenio`.
 */
@Injectable()
export class ConveniosModel {
  constructor(private readonly db: DatabaseService) {}

  /**
   * El front manda la palabra ('activos') y la base espera el número (1).
   * Traduzco acá para que la pantalla no tenga que conocer los códigos.
   */
  private resolveEstadoFiltro(estado?: ConvenioEstadoFiltro): number | null {
    if (estado === 'inactivos') return 0;
    if (estado === 'todos') return null;
    return 1;
  }

  listar(filtros: FiltroConveniosDto) {
    return this.db.callFunctionJson<AuthListResult>('cli_listar_convenios', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset ?? 0,
      this.resolveEstadoFiltro(filtros.estado),
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('cli_obtener_convenio', [id]);
  }

  listarCondicionesPago() {
    return this.db.callFunctionJson<{ registros: unknown[] }>(
      'cli_listar_condiciones_pago',
      [],
    );
  }

  crear(
    codigo: string,
    nombre: string,
    idCondicionPago: number,
    limiteCredito: number,
    corteQuincenal: boolean,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('cli_crear_convenio', [
      codigo,
      nombre,
      idCondicionPago,
      limiteCredito,
      corteQuincenal,
      idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(
    id: number,
    codigo: string | null,
    nombre: string | null,
    idCondicionPago: number | null,
    limiteCredito: number | null,
    corteQuincenal: boolean | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('cli_actualizar_convenio', [
      id,
      codigo,
      nombre,
      idCondicionPago,
      limiteCredito,
      corteQuincenal,
      idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('cli_eliminar_convenio', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  activar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthActivateResult>('cli_activar_convenio', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
