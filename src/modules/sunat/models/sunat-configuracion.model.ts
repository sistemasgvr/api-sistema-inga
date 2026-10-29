import { BadRequestException, Injectable } from '@nestjs/common';
import type {
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';

export interface ConfiguracionSunatRegistro {
  id_empresa: number;
  id: number | null;
  proveedor_ose: string | null;
  token_emision_cifrado: string | null;
  usuario_sol_cifrado: string | null;
  clave_sol_cifrada: string | null;
  certificado_cifrado: string | null;
  clave_certificado_cifrada: string | null;
  certificado_titular: string | null;
  certificado_vence: string | null;
  id_ambiente: number | null;
  dias_limite_envio_boleta: number | null;
  dias_limite_envio_factura: number | null;
  fecha_modificacion: string | null;
}

/** Valores a guardar; `undefined` conserva el actual. */
export interface CambiosConfiguracionSunat {
  tokenEmisionCifrado?: string;
  usuarioSolCifrado?: string;
  claveSolCifrada?: string;
  idAmbiente?: number;
  diasLimiteEnvioBoleta?: number;
  diasLimiteEnvioFactura?: number;
}

export interface CertificadoSunat {
  certificadoCifrado: string;
  claveCertificadoCifrada: string;
  titular: string | null;
  vence: Date | null;
}

type Resultado = AuthSingleResult<ConfiguracionSunatRegistro>;

function registro(result: Resultado) {
  if (result?.error) throw new BadRequestException(result.error);
  return result?.registro ?? null;
}

/** Una fila por empresa; siempre la de la sesión. */
@Injectable()
export class SunatConfiguracionModel {
  constructor(private readonly db: DatabaseService) {}

  async obtener(idEmpresa: number | null) {
    return registro(
      await this.db.callFunctionJson<Resultado>(
        'gen_obtener_configuracion_sunat',
        [idEmpresa],
      ),
    );
  }

  /** Empresas activas con token de APIsPERU: el programador las recorre todas. */
  async empresasActivas() {
    const result = await this.db.callFunctionJson<
      AuthListResult<{ id: number; ruc: string; razon_social: string }>
    >('gen_listar_empresas_sunat_activas');
    return result?.registros ?? [];
  }

  async guardar(
    idEmpresa: number,
    cambios: CambiosConfiguracionSunat,
    usuario: number,
  ) {
    return registro(
      await this.db.callFunctionJson<Resultado>(
        'gen_guardar_configuracion_sunat',
        [
          idEmpresa,
          JSON.stringify({
            token_emision_cifrado: cambios.tokenEmisionCifrado,
            usuario_sol_cifrado: cambios.usuarioSolCifrado,
            clave_sol_cifrada: cambios.claveSolCifrada,
            id_ambiente: cambios.idAmbiente,
            dias_limite_envio_boleta: cambios.diasLimiteEnvioBoleta,
            dias_limite_envio_factura: cambios.diasLimiteEnvioFactura,
          }),
          usuario,
        ],
      ),
    );
  }

  async guardarCertificado(
    idEmpresa: number,
    certificado: CertificadoSunat,
    usuario: number,
  ) {
    return registro(
      await this.db.callFunctionJson<Resultado>(
        'gen_guardar_certificado_sunat',
        [
          idEmpresa,
          JSON.stringify({
            certificado_cifrado: certificado.certificadoCifrado,
            clave_certificado_cifrada: certificado.claveCertificadoCifrada,
            certificado_titular: certificado.titular,
            certificado_vence: certificado.vence?.toISOString() ?? null,
          }),
          usuario,
        ],
      ),
    );
  }
}
