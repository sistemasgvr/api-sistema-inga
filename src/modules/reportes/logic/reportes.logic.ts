import { BadRequestException, Injectable } from '@nestjs/common';
import { FiltroReporteDto } from '../dto/reportes.dto';
import { FiltroPeriodo, ReportesModel } from '../models/reportes.model';

/** Un año y un día: alcanza para comparar un año completo sin cargar de más la base. */
const MAX_DIAS_RANGO = 366;

const DIA_MS = 24 * 60 * 60 * 1000;

/**
 * Orquesta las consultas de cada reporte. Devuelve sumas y filas tal como
 * salen de la base; los indicadores derivados (márgenes, utilidad, ticket
 * promedio, agrupación por semana o mes) los calcula el front a partir de
 * estas cifras, para que la misma regla sirva al gráfico y a la exportación.
 */
@Injectable()
export class ReportesLogic {
  constructor(private readonly model: ReportesModel) {}

  private periodo(filtros: FiltroReporteDto): FiltroPeriodo {
    const desde = Date.parse(`${filtros.fecha_desde.slice(0, 10)}T00:00:00Z`);
    const hasta = Date.parse(`${filtros.fecha_hasta.slice(0, 10)}T00:00:00Z`);
    if (Number.isNaN(desde) || Number.isNaN(hasta)) {
      throw new BadRequestException('Las fechas del reporte no son válidas');
    }
    if (desde > hasta) {
      throw new BadRequestException(
        'La fecha inicial no puede ser posterior a la final',
      );
    }
    if ((hasta - desde) / DIA_MS + 1 > MAX_DIAS_RANGO) {
      throw new BadRequestException(
        `El rango del reporte no puede superar ${MAX_DIAS_RANGO} días`,
      );
    }
    return {
      fecha_desde: filtros.fecha_desde.slice(0, 10),
      fecha_hasta: filtros.fecha_hasta.slice(0, 10),
      id_sucursal: filtros.id_sucursal ?? null,
    };
  }

  async dashboard(filtros: FiltroReporteDto) {
    const f = this.periodo(filtros);
    const [
      resumen_ventas,
      productos,
      por_dia,
      por_hora,
      por_dia_semana,
      por_tipo,
      por_medio,
      por_mozo,
      gastos_diarios,
      gastos_administrativos,
      planilla,
    ] = await Promise.all([
      this.model.resumenVentas(f),
      this.model.productosVendidos(f),
      this.model.ventasPorDia(f),
      this.model.ventasPorHora(f),
      this.model.ventasPorDiaSemana(f),
      this.model.ventasPorTipo(f),
      this.model.ventasPorMedio(f),
      this.model.ventasPorMozo(f),
      this.model.gastosDiariosPorDia(f),
      this.model.gastosAdministrativos(f),
      this.model.pagosPlanilla(f),
    ]);
    return {
      periodo: f,
      resumen_ventas,
      productos,
      por_dia,
      por_hora,
      por_dia_semana,
      por_tipo,
      por_medio,
      por_mozo,
      gastos_diarios,
      gastos_administrativos,
      planilla,
    };
  }

  async ventas(filtros: FiltroReporteDto) {
    const f = this.periodo(filtros);
    const [resumen_ventas, productos, por_medio, por_tipo, por_mozo, ventas] =
      await Promise.all([
        this.model.resumenVentas(f),
        this.model.productosVendidos(f),
        this.model.ventasPorMedio(f),
        this.model.ventasPorTipo(f),
        this.model.ventasPorMozo(f),
        this.model.listadoVentas(f),
      ]);
    return {
      periodo: f,
      resumen_ventas,
      productos,
      por_medio,
      por_tipo,
      por_mozo,
      ventas,
    };
  }

  async gastos(filtros: FiltroReporteDto) {
    const f = this.periodo(filtros);
    const [gastos_diarios, gastos_diarios_items, gastos_administrativos] =
      await Promise.all([
        this.model.gastosDiariosPorDia(f),
        this.model.gastosDiariosPorItem(f),
        this.model.gastosAdministrativos(f),
      ]);
    return {
      periodo: f,
      gastos_diarios,
      gastos_diarios_items,
      gastos_administrativos,
    };
  }

  async caja(filtros: FiltroReporteDto) {
    const f = this.periodo(filtros);
    const [turnos, movimientos] = await Promise.all([
      this.model.turnos(f),
      this.model.movimientosCaja(f),
    ]);
    return { periodo: f, turnos, movimientos };
  }

  async cuentas(filtros: FiltroReporteDto) {
    const f = this.periodo(filtros);
    const [por_cobrar, por_pagar] = await Promise.all([
      this.model.cuentasPorCobrar(f),
      this.model.cuentasPorPagar(f),
    ]);
    return { periodo: f, por_cobrar, por_pagar };
  }

  async planilla(filtros: FiltroReporteDto) {
    const f = this.periodo(filtros);
    return { periodo: f, pagos: await this.model.pagosPlanilla(f) };
  }

  async inventario(filtros: FiltroReporteDto) {
    const f = this.periodo(filtros);
    const [stock, movimientos] = await Promise.all([
      this.model.stock(f.id_sucursal),
      this.model.movimientosInventario(f),
    ]);
    return { periodo: f, stock, movimientos };
  }

  /** Estado de resultados del período y la foto de caja, cuentas e inventario. */
  async general(filtros: FiltroReporteDto) {
    const f = this.periodo(filtros);
    const [
      resumen_ventas,
      productos,
      por_medio,
      gastos_diarios,
      gastos_administrativos,
      planilla,
      turnos,
      por_cobrar,
      por_pagar,
      stock,
    ] = await Promise.all([
      this.model.resumenVentas(f),
      this.model.productosVendidos(f),
      this.model.ventasPorMedio(f),
      this.model.gastosDiariosPorDia(f),
      this.model.gastosAdministrativos(f),
      this.model.pagosPlanilla(f),
      this.model.turnos(f),
      this.model.cuentasPorCobrar(f),
      this.model.cuentasPorPagar(f),
      this.model.stock(f.id_sucursal),
    ]);
    return {
      periodo: f,
      resumen_ventas,
      productos,
      por_medio,
      gastos_diarios,
      gastos_administrativos,
      planilla,
      turnos,
      por_cobrar,
      por_pagar,
      stock,
    };
  }
}
