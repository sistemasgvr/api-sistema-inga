import { Injectable } from '@nestjs/common';
import {
  AuthActivateResult,
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  BuscarPersonasDto,
  FiltroPersonasDto,
  PersonaEstadoFiltro,
  PersonaRolFiltro,
} from '../dto/personas.dto';

/** Datos ya listos para mandar a `cli_crear_persona` / `cli_actualizar_persona`. */
export interface PersonaDbParams {
  tipoPersona: number | null;
  tipoDocumento: number | null;
  numDocumento: string | null;
  razonSocial: string | null;
  nombres: string | null;
  apellidoPaterno: string | null;
  apellidoMaterno: string | null;
  direccion: string | null;
  idDistrito: number | null;
  telefono: string | null;
  email: string | null;
  esCliente: boolean | null;
  esProveedor: boolean | null;
  idConvenio: number | null;
}

@Injectable()
export class PersonasModel {
  constructor(private readonly db: DatabaseService) {}

  private resolveEstadoFiltro(estado?: PersonaEstadoFiltro): number | null {
    if (estado === 'inactivos') return 0;
    if (estado === 'todos') return null;
    return 1;
  }

  /**
   * 'todos' viaja como null porque la función SQL entiende null como
   * "sin filtro de rol". Mando solo 'clientes' o 'proveedores'.
   */
  private resolveRolFiltro(rol?: PersonaRolFiltro): string | null {
    if (rol === 'clientes' || rol === 'proveedores') return rol;
    return null;
  }

  listar(filtros: FiltroPersonasDto, idEmpresa?: number | null) {
    return this.db.callFunctionJson<AuthListResult>('cli_listar_personas', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset ?? 0,
      this.resolveRolFiltro(filtros.rol),
      filtros.id_convenio ?? null,
      this.resolveEstadoFiltro(filtros.estado),
      idEmpresa ?? null,
    ]);
  }

  buscar(dto: BuscarPersonasDto, idEmpresa?: number | null) {
    return this.db.callFunctionJson<{ registros: unknown[] }>(
      'cli_buscar_personas',
      [
        dto.buscar ?? '',
        this.resolveRolFiltro(dto.rol),
        dto.limite ?? 15,
        idEmpresa ?? null,
      ],
    );
  }
  distritoPorUbigeo(ubigeo: string) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'gen_obtener_distrito_por_ubigeo',
      [ubigeo],
    );
  }

  distrito(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('gen_obtener_distrito', [
      id,
    ]);
  }

  obtenerPorId(id: number, idEmpresa?: number | null) {
    return this.db.callFunctionJson<AuthSingleResult>('cli_obtener_persona', [
      id,
      idEmpresa ?? null,
    ]);
  }

  crear(
    datos: PersonaDbParams,
    idUsuarioAuditoria?: number,
    idEmpresa?: number | null,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('cli_crear_persona', [
      datos.tipoPersona,
      datos.tipoDocumento,
      datos.numDocumento,
      datos.razonSocial,
      datos.nombres,
      datos.apellidoPaterno,
      datos.apellidoMaterno,
      datos.direccion,
      datos.idDistrito,
      datos.telefono,
      datos.email,
      datos.esCliente,
      datos.esProveedor,
      datos.idConvenio,
      idUsuarioAuditoria ?? null,
      idEmpresa ?? null,
    ]);
  }

  actualizar(
    id: number,
    datos: PersonaDbParams,
    quitarConvenio: boolean,
    idUsuarioAuditoria?: number,
    idEmpresa?: number | null,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'cli_actualizar_persona',
      [
        id,
        datos.tipoPersona,
        datos.tipoDocumento,
        datos.numDocumento,
        datos.razonSocial,
        datos.nombres,
        datos.apellidoPaterno,
        datos.apellidoMaterno,
        datos.direccion,
        datos.idDistrito,
        datos.telefono,
        datos.email,
        datos.esCliente,
        datos.esProveedor,
        datos.idConvenio,
        quitarConvenio,
        idUsuarioAuditoria ?? null,
        idEmpresa ?? null,
      ],
    );
  }

  eliminar(id: number, idUsuarioAuditoria?: number, idEmpresa?: number | null) {
    return this.db.callFunctionJson<AuthDeleteResult>('cli_eliminar_persona', [
      id,
      idUsuarioAuditoria ?? null,
      idEmpresa ?? null,
    ]);
  }

  activar(id: number, idUsuarioAuditoria?: number, idEmpresa?: number | null) {
    return this.db.callFunctionJson<AuthActivateResult>('cli_activar_persona', [
      id,
      idUsuarioAuditoria ?? null,
      idEmpresa ?? null,
    ]);
  }
}
