import { SetMetadata } from '@nestjs/common';
import type { PermisoBandera } from '../constants/permiso-banderas';

export const PERMISOS_KEY = 'permisos';

export const Permisos = (...permisos: PermisoBandera[]) =>
  SetMetadata(PERMISOS_KEY, permisos);

export const PERMISOS_ALGUNO_KEY = 'permisos_alguno';
export const PermisosAlguno = (...permisos: PermisoBandera[]) =>
  SetMetadata(PERMISOS_ALGUNO_KEY, permisos);
