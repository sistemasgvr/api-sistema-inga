import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  AbrirTurnoDto,
  CerrarTurnoDto,
  CreateMovimientoDto,
  ESTADO_TURNO,
  FiltroTurnosDto,
  GuardarArqueoDto,
} from '../dto/turnos.dto';
import { TurnosModel } from '../models/turnos.model';

/** Código del rol administrador en auth_rol. */
export const CODIGO_ROL_ADMIN = 'ADMIN';

type UsuarioRoles = {
  es_super_admin?: boolean;
  roles?: { codigo: string }[] | null;
};

/** Administrador: superadministrador o con el rol ADMIN activo. */
export function esAdministrador(usuario: UsuarioRoles | null | undefined) {
  return Boolean(
    usuario?.es_super_admin ||
    usuario?.roles?.some((rol) => rol.codigo === CODIGO_ROL_ADMIN),
  );
}

export function mensajeCierreNoAutorizado(nombreCajero?: string | null) {
  const cajero = nombreCajero?.trim() || 'el cajero que la abrió';
  return `Solo ${cajero}, quien abrió esta caja, o un administrador puede cerrarla.`;
}

@Injectable()
export class TurnosLogic {
  constructor(private readonly turnosModel: TurnosModel) {}

  async listar(filtros: FiltroTurnosDto) {
    const result = await this.turnosModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.turnosModel.obtenerPorId(id);
    return mapSingleResult(result, `Turno con ID ${id} no encontrado`);
  }

  /**
   * Devuelve el turno abierto del cajero, o `null` si no tiene ninguno.
   *
   * Acá NO uso `mapSingleResult` a propósito: ese helper lanza un 404 cuando no
   * hay registro, y en este caso "no tiene turno abierto" no es un error, es la
   * respuesta normal cuando el cajero recién llega. La pantalla necesita
   * distinguir las dos cosas para saber si muestra el panel del turno o el
   * formulario de apertura.
   */
  async obtenerAbiertoPorCajero(idCajero: number) {
    const result = await this.turnosModel.obtenerAbiertoPorCajero(idCajero);
    return { registro: result?.registro ?? null };
  }

  /**
   * Turno contra el que se registran cobros, pagos y gastos: basta una caja
   * abierta, no hace falta que la haya abierto el usuario. Igual que arriba,
   * `null` no es un error: significa que no hay caja abierta.
   */
  async obtenerVigente(idUsuario: number, idSucursal: number | null) {
    const result = await this.turnosModel.obtenerVigente(idUsuario, idSucursal);
    return { registro: result?.registro ?? null };
  }

  async resumen(id: number) {
    const result = await this.turnosModel.resumen(id);

    if (!result?.registro) {
      throw new NotFoundException(`Turno con ID ${id} no encontrado`);
    }

    return result.registro;
  }

  async abrir(dto: AbrirTurnoDto) {
    const result = await this.turnosModel.abrir(
      dto.id_caja,
      dto.id_cajero,
      dto.monto_apertura ?? 0,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo abrir el turno');
  }

  /**
   * Una caja abierta solo la cierra el cajero del turno o un administrador
   * (aunque no sea su turno). Lo mismo vale para el arqueo, que es parte del
   * cierre: si no, otro usuario podría pisar el conteo antes de recibir el 403.
   * Un turno ya cerrado pasa: la función SQL responde que ya fue cerrado.
   */
  private async validarCierre(idTurno: number, idUsuario?: number) {
    const result = await this.turnosModel.obtenerPorId(idTurno);
    const turno = result?.registro as {
      id_cajero: number;
      nombre_cajero?: string | null;
      estado_turno: number;
    } | null;

    if (!turno) {
      throw new NotFoundException(`Turno con ID ${idTurno} no encontrado`);
    }

    if (
      Number(turno.estado_turno) !== ESTADO_TURNO.ABIERTO ||
      (idUsuario != null && Number(turno.id_cajero) === Number(idUsuario))
    ) {
      return;
    }

    const usuario =
      idUsuario != null
        ? (await this.turnosModel.obtenerUsuario(idUsuario))?.registro
        : null;

    if (!esAdministrador(usuario)) {
      throw new ForbiddenException(
        mensajeCierreNoAutorizado(turno.nombre_cajero),
      );
    }
  }

  async cerrar(id: number, dto: CerrarTurnoDto) {
    await this.validarCierre(id, dto.idUsuarioAuditoria);
    const result = await this.turnosModel.cerrar(id, dto);
    return mapSingleResult(result, `Turno con ID ${id} no encontrado`);
  }

  async registrarMovimiento(idTurno: number, dto: CreateMovimientoDto) {
    const result = await this.turnosModel.registrarMovimiento(idTurno, dto);
    return mapSingleResult(result, 'No se pudo registrar el movimiento');
  }

  async listarMovimientos(idTurno: number) {
    return await this.turnosModel.listarMovimientos(idTurno);
  }

  async anularMovimiento(id: number, idUsuarioAuditoria?: number) {
    const result = await this.turnosModel.anularMovimiento(
      id,
      idUsuarioAuditoria,
    );
    return mapDeleteResult(
      result,
      `Movimiento con ID ${id} no encontrado o ya anulado`,
    );
  }

  async guardarArqueo(idTurno: number, dto: GuardarArqueoDto) {
    await this.validarCierre(idTurno, dto.idUsuarioAuditoria);
    const result = await this.turnosModel.guardarArqueo(
      idTurno,
      dto.detalle,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Turno con ID ${idTurno} no encontrado`);
  }
}
