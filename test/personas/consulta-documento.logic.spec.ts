import { BadRequestException, NotFoundException } from '@nestjs/common';
import { ConsultaDocumentoLogic } from '../../src/modules/personas/logic/consulta-documento.logic';
import { PersonasModel } from '../../src/modules/personas/models/personas.model';
import { ApisPeruConsultasService } from '../../src/integrations/apisperu/apisperu-consultas.service';
import { ApisPeruFallo } from '../../src/integrations/apisperu/apisperu.service';

describe('Consulta de DNI / RUC', () => {
  const model = {
    buscar: jest.fn(),
    obtenerPorId: jest.fn(),
    distrito: jest.fn(),
    distritoPorUbigeo: jest.fn(),
  };
  const consultas = { dni: jest.fn(), ruc: jest.fn() };
  const logic = new ConsultaDocumentoLogic(
    model as unknown as PersonasModel,
    consultas as unknown as ApisPeruConsultasService,
  );
  beforeEach(() => {
    jest.resetAllMocks();
    model.buscar.mockResolvedValue({ registros: [] });
  });

  it('rechaza números que no son DNI ni RUC', async () => {
    await expect(logic.consultar('123', 1)).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(consultas.dni).not.toHaveBeenCalled();
  });

  it('devuelve el cliente registrado de la empresa sin consultar afuera', async () => {
    model.buscar.mockResolvedValue({
      registros: [{ id: 5, num_documento: '12345678' }],
    });
    model.obtenerPorId.mockResolvedValue({
      registro: {
        id: 5,
        tipo_persona: 1,
        tipo_documento: 1,
        num_documento: '12345678',
        nombre_completo: 'ANA PEREZ',
        id_distrito: null,
        es_cliente: true,
      },
    });
    const r = await logic.consultar('12345678', 1);
    expect(r).toMatchObject({
      origen: 'registrado',
      id_persona: 5,
      nombre: 'ANA PEREZ',
    });
    expect(model.buscar).toHaveBeenCalledWith(
      { buscar: '12345678', limite: 10 },
      1,
    );
    expect(consultas.dni).not.toHaveBeenCalled();
  });

  it('consulta RENIEC para un DNI no registrado', async () => {
    consultas.dni.mockResolvedValue({
      dni: '12345678',
      nombres: 'ANA',
      apellidoPaterno: 'PEREZ',
      apellidoMaterno: 'RUIZ',
    });
    await expect(logic.consultar('12345678', 1)).resolves.toMatchObject({
      origen: 'reniec',
      tipo_documento: 1,
      nombre: 'ANA PEREZ RUIZ',
      apellido_materno: 'RUIZ',
    });
  });

  it('consulta SUNAT para un RUC y resuelve el distrito por ubigeo', async () => {
    consultas.ruc.mockResolvedValue({
      ruc: '20131312955',
      razonSocial: 'EMPRESA SAC',
      nombreComercial: '-',
      estado: 'ACTIVO',
      condicion: 'HABIDO',
      direccion: 'AV. LIMA 123',
      ubigeo: '150101',
    });
    model.distritoPorUbigeo.mockResolvedValue({
      registro: {
        id: 9,
        ubigeo: '150101',
        distrito: 'LIMA',
        provincia: 'LIMA',
        departamento: 'LIMA',
      },
    });
    const r = await logic.consultar('20131312955', 1);
    expect(r).toMatchObject({
      origen: 'sunat',
      tipo_documento: 6,
      tipo_persona: 2,
      razon_social: 'EMPRESA SAC',
      nombre_comercial: null,
      condicion: 'HABIDO',
      distrito: { id: 9 },
    });
  });

  it('responde 404 si APIsPERU no encuentra el documento', async () => {
    consultas.dni.mockRejectedValue(
      new ApisPeruFallo('No encontrado', 404, false),
    );
    await expect(logic.consultar('87654321', 1)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});
