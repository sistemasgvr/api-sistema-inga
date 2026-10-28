import {
  BadRequestException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import forge from 'node-forge';
import { SunatCifradoLogic } from '../../src/modules/sunat/logic/sunat-cifrado.logic';
import { leerCertificado } from '../../src/modules/sunat/logic/sunat-configuracion.logic';

const cifrado = (llave?: string) =>
  new SunatCifradoLogic(
    new ConfigService(llave ? { SUNAT_CRYPTO_KEY: llave } : {}),
  );

describe('Cifrado de credenciales SUNAT', () => {
  const logic = cifrado('llave-de-pruebas-de-32-caracteres!!');

  it('cifra con IV aleatorio y descifra el mismo valor', () => {
    const a = logic.cifrar('token-secreto');
    const b = logic.cifrar('token-secreto');
    expect(a).not.toBe(b);
    expect(a).not.toContain('token-secreto');
    expect(logic.descifrar(a)).toBe('token-secreto');
  });

  it('no descifra con otra llave ni un valor alterado', () => {
    const valor = logic.cifrar('clave');
    expect(() =>
      cifrado('otra-llave-de-pruebas-de-32-caracteres').descifrar(valor),
    ).toThrow(ServiceUnavailableException);
    const [v, iv, tag, datos] = valor.split('.');
    const alterado = [
      v,
      iv,
      tag,
      Buffer.from('xx' + datos).toString('base64'),
    ].join('.');
    expect(() => logic.descifrar(alterado)).toThrow(
      ServiceUnavailableException,
    );
  });

  it('sin SUNAT_CRYPTO_KEY no guarda credenciales', () => {
    expect(cifrado().configurado()).toBe(false);
    expect(() => cifrado().cifrar('x')).toThrow(ServiceUnavailableException);
  });
});

describe('Certificado digital', () => {
  // .pfx de prueba generado al vuelo (clave RSA de 1024 bits para que sea rápido).
  const keys = forge.pki.rsa.generateKeyPair(1024);
  const cert = forge.pki.createCertificate();
  cert.publicKey = keys.publicKey;
  cert.serialNumber = '01';
  cert.validity.notBefore = new Date('2026-01-01T00:00:00Z');
  cert.validity.notAfter = new Date('2027-01-01T00:00:00Z');
  const atributos = [{ name: 'commonName', value: 'RESTAURANTE INGA SAC' }];
  cert.setSubject(atributos);
  cert.setIssuer(atributos);
  cert.sign(keys.privateKey);
  const pfx = Buffer.from(
    forge.asn1
      .toDer(
        forge.pkcs12.toPkcs12Asn1(keys.privateKey, [cert], 'secreta', {
          algorithm: '3des',
        }),
      )
      .getBytes(),
    'binary',
  );

  it('lee titular, vencimiento y lo pasa a PEM con la llave', () => {
    const leido = leerCertificado(pfx, 'secreta');
    expect(leido.titular).toBe('RESTAURANTE INGA SAC');
    expect(leido.vence?.toISOString()).toBe('2027-01-01T00:00:00.000Z');
    expect(leido.pem).toContain('-----BEGIN RSA PRIVATE KEY-----');
    expect(leido.pem).toContain('-----BEGIN CERTIFICATE-----');
  });

  it('rechaza una contraseña incorrecta', () => {
    expect(() => leerCertificado(pfx, 'otra')).toThrow(BadRequestException);
  });
});
