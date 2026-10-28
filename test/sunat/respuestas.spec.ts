import { EstadoSunat } from '../../src/modules/sunat/constants/sunat';
import {
  interpretarComprobante,
  interpretarTicket,
} from '../../src/modules/sunat/helpers/respuestas';

describe('Respuestas de SUNAT', () => {
  it('acepta con CDR y conserva las observaciones', () => {
    expect(
      interpretarComprobante({
        success: true,
        cdrZip: 'UEsDBA==',
        cdrResponse: {
          accepted: true,
          code: '0',
          description: 'La Factura numero F001-5, ha sido aceptada',
          notes: ['4252 - observación'],
        },
      }),
    ).toEqual({
      estado: EstadoSunat.ACEPTADO,
      codigo: '0',
      mensaje: 'La Factura numero F001-5, ha sido aceptada',
      observaciones: '4252 - observación',
      cdrZip: 'UEsDBA==',
    });
  });

  it('un CDR con código de rechazo deja el comprobante rechazado', () => {
    expect(
      interpretarComprobante({
        success: true,
        cdrResponse: { code: '2800', description: 'Documento inválido' },
      }).estado,
    ).toBe(EstadoSunat.RECHAZADO);
  });

  it.each([
    ['2335', EstadoSunat.RECHAZADO],
    ['0109', EstadoSunat.PENDIENTE],
    ['HTTP', EstadoSunat.PENDIENTE],
    ['1033', EstadoSunat.ACEPTADO],
  ])('error %s sin CDR → estado %d', (code, estado) => {
    expect(
      interpretarComprobante({ success: false, error: { code, message: 'x' } })
        .estado,
    ).toBe(estado);
  });

  it('sin respuesta de SUNAT queda pendiente', () => {
    expect(interpretarComprobante(undefined).estado).toBe(
      EstadoSunat.PENDIENTE,
    );
  });

  it('el ticket 98 sigue en proceso; con CDR se resuelve', () => {
    expect(interpretarTicket({ code: '98' }).estado).toBe(
      EstadoSunat.EN_PROCESO,
    );
    expect(
      interpretarTicket({
        success: true,
        code: '0',
        cdrResponse: { accepted: true, code: '0', description: 'ok' },
      }).estado,
    ).toBe(EstadoSunat.ACEPTADO);
    expect(
      interpretarTicket({
        success: false,
        error: { code: '0127', message: 'ticket' },
      }).estado,
    ).toBe(EstadoSunat.RECHAZADO);
  });
});
