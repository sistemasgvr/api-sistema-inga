import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import forge from 'node-forge';
import {
  ApisPeruFallo,
  ApisPeruService,
} from '../../../integrations/apisperu/apisperu.service';
import { GuardarConfiguracionSunatDto } from '../dto/sunat.dto';
import {
  construirFactura,
  validarEmisor,
  type EmisorSunat,
} from '../helpers/documentos';
import { SunatComprobantesModel } from '../models/sunat-comprobantes.model';
import { SunatConfiguracionModel } from '../models/sunat-configuracion.model';
import { SunatCifradoLogic } from './sunat-cifrado.logic';

const enmascarar = (valor: string) =>
  valor.length <= 4
    ? '****'
    : `${'*'.repeat(valor.length - 4)}${valor.slice(-4)}`;

export interface CertificadoLeido {
  pem: string;
  titular: string | null;
  vence: Date | null;
}

/** Abre el .pfx/.p12 con su contraseña y lo pasa a PEM (llave + certificado), como lo usa APIsPERU. */
export function leerCertificado(
  archivo: Buffer,
  clave: string,
): CertificadoLeido {
  let p12: forge.pkcs12.Pkcs12Pfx;
  try {
    const asn1 = forge.asn1.fromDer(archivo.toString('binary'));
    p12 = forge.pkcs12.pkcs12FromAsn1(asn1, clave);
  } catch {
    throw new BadRequestException(
      'No se pudo abrir el certificado: verifique que sea un .pfx/.p12 y que la contraseña sea correcta',
    );
  }
  const certificados =
    p12.getBags({ bagType: forge.pki.oids.certBag })[forge.pki.oids.certBag] ??
    [];
  const llaves =
    p12.getBags({ bagType: forge.pki.oids.pkcs8ShroudedKeyBag })[
      forge.pki.oids.pkcs8ShroudedKeyBag
    ] ??
    p12.getBags({ bagType: forge.pki.oids.keyBag })[forge.pki.oids.keyBag] ??
    [];
  const certificado = certificados.find((b) => b.cert)?.cert;
  const llave = llaves.find((b) => b.key)?.key;
  if (!certificado || !llave)
    throw new BadRequestException(
      'El archivo no contiene el certificado y su llave privada',
    );
  const atributo = (nombre: string) =>
    (certificado.subject.getField(nombre) as { value?: string } | null)?.value;
  return {
    pem:
      forge.pki.privateKeyToPem(llave) +
      forge.pki.certificateToPem(certificado),
    titular: atributo('CN') ?? atributo('O') ?? null,
    vence: certificado.validity?.notAfter ?? null,
  };
}

/**
 * Configuración SUNAT de la vista Empresa. Los secretos se guardan cifrados y
 * nunca se devuelven: la respuesta solo dice qué está cargado.
 */
@Injectable()
export class SunatConfiguracionLogic {
  constructor(
    private readonly model: SunatConfiguracionModel,
    private readonly comprobantes: SunatComprobantesModel,
    private readonly cifrado: SunatCifradoLogic,
    private readonly apisPeru: ApisPeruService,
  ) {}

  async obtener() {
    const c = await this.model.obtener();
    if (!c)
      throw new NotFoundException(
        'Primero guarda el RUC y la razón social de la empresa',
      );
    let usuarioSol: string | null = null;
    if (c.usuario_sol_cifrado && this.cifrado.configurado()) {
      try {
        usuarioSol = enmascarar(this.cifrado.descifrar(c.usuario_sol_cifrado));
      } catch {
        usuarioSol = null;
      }
    }
    const emisor = await this.comprobantes.emisor();
    return {
      proveedor: c.proveedor_ose ?? 'APISPERU',
      idAmbiente: c.id_ambiente ?? 1,
      tieneToken: Boolean(c.token_emision_cifrado),
      tieneUsuarioSol: Boolean(c.usuario_sol_cifrado),
      usuarioSol,
      tieneClaveSol: Boolean(c.clave_sol_cifrada),
      tieneCertificado: Boolean(c.certificado_cifrado),
      certificadoTitular: c.certificado_titular,
      certificadoVence: c.certificado_vence,
      diasLimiteEnvioBoleta: c.dias_limite_envio_boleta ?? 3,
      diasLimiteEnvioFactura: c.dias_limite_envio_factura ?? 7,
      cifradoConfigurado: this.cifrado.configurado(),
      // Lo que falta en Empresa para que SUNAT acepte los comprobantes.
      datosEmpresaFaltantes: emisor ? validarEmisor(emisor) : [],
      fechaModificacion: c.fecha_modificacion,
    };
  }

  async guardar(dto: GuardarConfiguracionSunatDto, usuario: number) {
    const c = await this.requerida();
    const cifrar = (valor?: string) =>
      valor ? this.cifrado.cifrar(valor) : undefined;
    await this.model.guardar(
      c.id_empresa,
      {
        tokenEmisionCifrado: cifrar(dto.tokenEmision),
        usuarioSolCifrado: cifrar(dto.usuarioSol),
        claveSolCifrada: cifrar(dto.claveSol),
        idAmbiente: dto.idAmbiente,
        diasLimiteEnvioBoleta: dto.diasLimiteEnvioBoleta,
        diasLimiteEnvioFactura: dto.diasLimiteEnvioFactura,
      },
      usuario,
    );
    return this.obtener();
  }

  async subirCertificado(
    file: Express.Multer.File | undefined,
    clave: string,
    usuario: number,
  ) {
    if (!file?.buffer?.length)
      throw new BadRequestException('Adjunte el certificado (.pfx o .p12)');
    const c = await this.requerida();
    const leido = leerCertificado(file.buffer, clave);
    if (leido.vence && leido.vence.getTime() < Date.now())
      throw new BadRequestException(
        `El certificado venció el ${leido.vence.toISOString().slice(0, 10)}`,
      );
    await this.model.guardarCertificado(
      c.id_empresa,
      {
        certificadoCifrado: this.cifrado.cifrar(leido.pem),
        claveCertificadoCifrada: this.cifrado.cifrar(clave),
        titular: leido.titular,
        vence: leido.vence,
      },
      usuario,
    );
    return this.obtener();
  }

  /**
   * Valida el token pidiendo a APIsPERU el XML de una boleta de prueba: no se envía
   * a SUNAT ni consume correlativos.
   */
  async probar() {
    const { emisor, token } = await this.contexto();
    const prueba = construirFactura(
      {
        id: 0,
        tipoComprobante: 1,
        serie: 'B999',
        correlativo: '1',
        fechaEmision: new Date().toISOString(),
        receptorTipoDoc: 1,
        receptorNumDoc: '00000000',
        receptorRazonSocial: 'CLIENTES VARIOS',
        receptorDireccion: null,
        lineas: [
          {
            idProducto: null,
            descripcion: 'PRUEBA DE CONEXION',
            cantidad: 1,
            unidadSunat: 'NIU',
            tipoAfectacionIgv: '10',
            tasaIgv: 18,
            valorUnitario: 1,
            precioUnitarioIgv: 1.18,
            montoBaseIgv: 1,
            montoIgv: 0.18,
          },
        ],
      },
      emisor,
    );
    try {
      await this.apisPeru.xmlFactura(token, prueba);
    } catch (error) {
      if (error instanceof ApisPeruFallo)
        throw new BadRequestException(error.message);
      throw error;
    }
    return {
      ok: true,
      mensaje: 'APIsPERU aceptó el token y los datos de la empresa',
    };
  }

  /** Emisor completo y token descifrado; falla con un mensaje claro si falta algo. */
  async contexto(): Promise<{ emisor: EmisorSunat; token: string }> {
    const emisor = await this.comprobantes.emisor();
    if (!emisor)
      throw new BadRequestException(
        'Primero guarda los datos de la empresa en Configuración → Empresa',
      );
    const faltan = validarEmisor(emisor);
    if (faltan.length)
      throw new BadRequestException(
        `Complete en Configuración → Empresa: ${faltan.join(', ')}`,
      );
    if (!emisor.tokenCifrado)
      throw new BadRequestException(
        'Registre el token de APIsPERU en Configuración → Empresa → SUNAT',
      );
    return { emisor, token: this.cifrado.descifrar(emisor.tokenCifrado) };
  }

  /** true si hay token y llave de cifrado: el programador solo trabaja así. */
  async lista() {
    if (!this.cifrado.configurado()) return false;
    const emisor = await this.comprobantes.emisor();
    return Boolean(emisor?.tokenCifrado) && !validarEmisor(emisor!).length;
  }

  private async requerida() {
    const c = await this.model.obtener();
    if (!c)
      throw new NotFoundException(
        'Primero guarda el RUC y la razón social de la empresa',
      );
    return c;
  }
}
