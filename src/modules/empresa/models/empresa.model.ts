import { BadRequestException, Injectable } from '@nestjs/common';
import type {
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';

export interface EmpresaRegistro {
  id: number;
  ruc: string;
  razon_social: string;
  nombre_comercial: string | null;
  direccion: string | null;
  id_distrito: number | null;
  tasa_igv: number;
  logo_url: string | null;
  logo_ticket: string | null;
}

export interface DistritoRegistro {
  id: number;
  codigo_ubigeo: string | null;
  distrito: string;
  provincia: string;
  departamento: string;
}

export interface DatosEmpresa {
  ruc: string;
  razonSocial: string;
  nombreComercial: string | null;
  direccion: string | null;
  idDistrito: number | null;
  tasaIgv: number;
}

/** Las validaciones de gen_guardar_* llegan como { error }: se devuelven como 400. */
function registro<T>(result: AuthSingleResult<T>) {
  if (result?.error) throw new BadRequestException(result.error);
  return (result?.registro ?? null) as T;
}

/**
 * La empresa es la del usuario autenticado (la de su trabajador): nunca se toma
 * «la primera activa». La configuración SUNAT cuelga de esta misma fila.
 */
@Injectable()
export class EmpresaModel {
  constructor(private readonly db: DatabaseService) {}

  async obtener(idEmpresa: number | null) {
    return registro(
      await this.db.callFunctionJson<AuthSingleResult<EmpresaRegistro>>(
        'gen_obtener_empresa',
        [idEmpresa],
      ),
    );
  }

  async guardar(
    datos: DatosEmpresa,
    usuario: number,
    idEmpresa: number | null,
  ) {
    return registro(
      await this.db.callFunctionJson<AuthSingleResult<EmpresaRegistro>>(
        'gen_guardar_empresa',
        [
          JSON.stringify({
            ruc: datos.ruc,
            razon_social: datos.razonSocial,
            nombre_comercial: datos.nombreComercial,
            direccion: datos.direccion,
            id_distrito: datos.idDistrito,
            tasa_igv: datos.tasaIgv,
          }),
          usuario,
          idEmpresa,
        ],
      ),
    );
  }

  async guardarLogo(
    id: number,
    logoUrl: string | null,
    logoTicket: string | null,
    usuario: number,
  ) {
    return registro(
      await this.db.callFunctionJson<AuthSingleResult<EmpresaRegistro>>(
        'gen_guardar_logo_empresa',
        [id, logoUrl, logoTicket, usuario],
      ),
    );
  }

  async distrito(id: number) {
    return registro(
      await this.db.callFunctionJson<AuthSingleResult<DistritoRegistro>>(
        'gen_obtener_distrito',
        [id],
      ),
    );
  }

  async buscarDistritos(buscar: string) {
    const result = await this.db.callFunctionJson<
      AuthListResult<DistritoRegistro>
    >('gen_buscar_distritos', [buscar, 50]);
    return result?.registros ?? [];
  }
}
