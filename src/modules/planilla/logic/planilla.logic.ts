import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  mapActivateResult,
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreatePagoDto,
  CreateTrabajadorDto,
  FiltroPagosDto,
  FiltroReportePeriodoDto,
  FiltroTrabajadoresDto,
  UpdateTrabajadorDto,
} from '../dto/planilla.dto';
import { PlanillaModel } from '../models/planilla.model';
import { NotificacionesLogic } from '../../notificaciones/logic/notificaciones.logic';
import { RutasNotificacion } from '../../notificaciones/constants/rutas-notificacion';

type PagoNotificado = {
  id?: number;
  nombre_trabajador?: string;
  monto?: number | string;
  anio?: number;
  mes?: number;
  quincena?: number;
} | null;

@Injectable()
export class PlanillaLogic {
  constructor(
    private readonly planillaModel: PlanillaModel,
    private readonly notificaciones: NotificacionesLogic,
  ) {}

  async listarTrabajadores(
    filtros: FiltroTrabajadoresDto,
    idEmpresa?: number | null,
  ) {
    const result = await this.planillaModel.listarTrabajadores(
      filtros,
      idEmpresa,
    );
    return mapListResult(result, filtros);
  }

  async obtenerTrabajador(id: number, idEmpresa?: number | null) {
    const result = await this.planillaModel.obtenerTrabajador(id, idEmpresa);
    return mapSingleResult(result, `Trabajador con ID ${id} no encontrado`);
  }

  async crearTrabajador(dto: CreateTrabajadorDto, idEmpresa: number | null) {
    try {
      const result = await this.planillaModel.crearTrabajador(dto, idEmpresa);
      return mapSingleResult(result, 'No se pudo crear el trabajador');
    } catch (error) {
      this.errorTrabajador(error);
    }
  }

  async actualizarTrabajador(
    id: number,
    dto: UpdateTrabajadorDto,
    idEmpresa: number | null,
  ) {
    try {
      const result = await this.planillaModel.actualizarTrabajador(
        id,
        dto,
        idEmpresa,
      );
      return mapSingleResult(result, `Trabajador con ID ${id} no encontrado`);
    } catch (error) {
      this.errorTrabajador(error);
    }
  }

  private errorTrabajador(error: unknown): never {
    const dbError = error as {
      code?: string;
      constraint?: string;
      message?: string;
    };
    if (
      dbError.code === '23505' &&
      dbError.constraint === 'uq_pla_trabajador_email'
    ) {
      throw new ConflictException(
        'Ya existe un trabajador con ese correo electrónico.',
      );
    }
    if (dbError.code === 'P0001')
      throw new BadRequestException(dbError.message);
    throw error;
  }

  async eliminarTrabajador(
    id: number,
    idUsuarioAuditoria?: number,
    idEmpresa?: number | null,
  ) {
    const result = await this.planillaModel.eliminarTrabajador(
      id,
      idUsuarioAuditoria,
      idEmpresa,
    );
    return mapDeleteResult(
      result,
      `Trabajador con ID ${id} no encontrado o ya inactivo`,
    );
  }

  async activarTrabajador(
    id: number,
    idUsuarioAuditoria?: number,
    idEmpresa?: number | null,
  ) {
    const result = await this.planillaModel.activarTrabajador(
      id,
      idUsuarioAuditoria,
      idEmpresa,
    );
    return mapActivateResult(
      result,
      `Trabajador con ID ${id} no encontrado o ya activo`,
    );
  }

  async listarPagos(filtros: FiltroPagosDto, idEmpresa?: number | null) {
    const result = await this.planillaModel.listarPagos(filtros, idEmpresa);
    return mapListResult(result, filtros);
  }

  async obtenerPago(id: number, idEmpresa?: number | null) {
    const result = await this.planillaModel.obtenerPago(id, idEmpresa);
    return mapSingleResult(result, `Pago con ID ${id} no encontrado`);
  }

  async registrarPago(dto: CreatePagoDto, idEmpresa?: number | null) {
    const result = await this.planillaModel.registrarPago(dto, idEmpresa);
    const registro = mapSingleResult(result, 'No se pudo registrar el pago');
    this.notificarPago('registrado', registro, undefined, idEmpresa);
    return registro;
  }

  async anularPago(
    id: number,
    motivo?: string,
    idUsuarioAuditoria?: number,
    idEmpresa?: number | null,
  ) {
    // Se lee antes de anular para poder contar en el aviso de quién era el pago.
    const pago = await this.planillaModel
      .obtenerPago(id, idEmpresa)
      .then((r) => (r as { registro?: PagoNotificado })?.registro ?? null)
      ?.catch(() => null);
    const result = await this.planillaModel.anularPago(
      id,
      motivo,
      idUsuarioAuditoria,
      idEmpresa,
    );
    const respuesta = mapDeleteResult(
      result,
      `Pago con ID ${id} no encontrado o ya anulado`,
    );
    if (pago) this.notificarPago('anulado', { ...pago, id }, motivo, idEmpresa);
    return respuesta;
  }

  private notificarPago(
    evento: 'registrado' | 'anulado',
    pago: PagoNotificado,
    motivo?: string,
    idEmpresa?: number | null,
  ) {
    if (!pago) return;
    const quincena = `${pago.quincena === 1 ? '1ra' : '2da'} quincena ${pago.mes}/${pago.anio}`;
    const detalle = `${pago.nombre_trabajador ?? 'Trabajador'} · S/ ${Number(pago.monto ?? 0).toFixed(2)} · ${quincena}`;
    this.notificaciones
      .emitir({
        canal: 'planilla',
        titulo:
          evento === 'registrado'
            ? 'Pago de planilla registrado'
            : 'Pago de planilla anulado',
        mensaje:
          evento === 'anulado' && motivo?.trim()
            ? `${detalle}. Motivo: ${motivo.trim()}`
            : detalle,
        severidad: evento === 'registrado' ? 'success' : 'warning',
        ruta: RutasNotificacion.planilla(
          Number(pago.anio),
          Number(pago.mes),
          Number(pago.quincena),
        ),
        idReferencia: pago.id ?? null,
        idEmpresa,
      })
      ?.catch(() => undefined);
  }

  async reportePeriodo(
    filtros: FiltroReportePeriodoDto,
    idEmpresa?: number | null,
  ) {
    const result = await this.planillaModel.reportePeriodo(filtros, idEmpresa);

    if (!result?.registro) {
      throw new NotFoundException('No se pudo generar el reporte del período');
    }

    return result.registro;
  }
}
