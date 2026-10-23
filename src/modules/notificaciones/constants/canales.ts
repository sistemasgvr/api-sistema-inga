import {
  PermisoBanderas,
  PermisoBandera,
} from '../../../common/constants/permiso-banderas';
import { AuthenticatedUser } from '../../../common/interfaces/authenticated-user.interface';

// Canal -> permiso requerido para recibirlo (null = cualquier autenticado).
export const CANAL_PERMISO = {
  pedidos: PermisoBanderas.PEDIDOS_VER,
  cocina: PermisoBanderas.PRODUCCION_PREPARAR,
  caja: PermisoBanderas.TURNOS_LISTAR,
  inventario: PermisoBanderas.INVENTARIO_VER,
  ventas: PermisoBanderas.VENTAS_LISTAR,
  planilla: PermisoBanderas.PLANILLA_PAGOS_LISTAR,
  'cuentas-por-pagar': PermisoBanderas.CXP_LISTAR,
  'cuentas-por-cobrar': PermisoBanderas.CXC_LISTAR,
  gastos: PermisoBanderas.GASTOS_LISTAR,
  'gastos-diarios': PermisoBanderas.GDO_LISTAR,
  sistema: null,
} as const satisfies Record<string, PermisoBandera | null>;

export type CanalNotificacion = keyof typeof CANAL_PERMISO;

export const CANALES_VALIDOS = Object.keys(
  CANAL_PERMISO,
) as CanalNotificacion[];

export const SEVERIDADES = ['info', 'success', 'warning', 'error'] as const;

export type SeveridadNotificacion = (typeof SEVERIDADES)[number];

/** Días que se conserva el historial de notificaciones. */
export const DIAS_HISTORIAL = 60;

/** Canales que el usuario puede recibir según sus permisos. */
export function canalesPermitidos(
  user: Pick<AuthenticatedUser, 'es_super_admin' | 'permisos'>,
  canales: readonly string[] = CANALES_VALIDOS,
): CanalNotificacion[] {
  return canales.filter((c): c is CanalNotificacion => {
    if (!Object.hasOwn(CANAL_PERMISO, c)) return false;
    const permiso = CANAL_PERMISO[c as CanalNotificacion];
    if (permiso === null || user.es_super_admin) return true;
    return user.permisos.includes(permiso);
  });
}
