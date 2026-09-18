import { Injectable, NotFoundException } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  AbrirTurnoDto,
  CerrarTurnoDto,
  CreateMovimientoDto,
  FiltroTurnosDto,
  GuardarArqueoDto,
} from '../dto/turnos.dto';
import { TurnosModel } from '../models/turnos.model';

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

  async cerrar(id: number, dto: CerrarTurnoDto) {
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
    const result = await this.turnosModel.anularMovimiento(id, idUsuarioAuditoria);
    return mapDeleteResult(
      result,
      `Movimiento con ID ${id} no encontrado o ya anulado`,
    );
  }

  async guardarArqueo(idTurno: number, dto: GuardarArqueoDto) {
    const result = await this.turnosModel.guardarArqueo(
      idTurno,
      dto.detalle,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Turno con ID ${idTurno} no encontrado`);
  }
}
