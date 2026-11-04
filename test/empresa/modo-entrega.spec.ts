import { EmpresaLogic } from '../../src/modules/empresa/logic/empresa.logic';
import { EmpresaModel } from '../../src/modules/empresa/models/empresa.model';
import { SupabaseStorageService } from '../../src/integrations/supabase-storage/supabase-storage.service';

const empresa = {
  id: 1,
  ruc: '20000000001',
  razon_social: 'INGA S.A.C.',
  nombre_comercial: null,
  direccion: null,
  id_distrito: null,
  tasa_igv: 18,
  modo_entrega_directa: 0,
  logo_url: null,
  logo_ticket: null,
};

const dtoBase = {
  ruc: '20000000001',
  razonSocial: 'INGA S.A.C.',
};

describe('EmpresaLogic · modo de entrega directa', () => {
  const model = {
    obtener: jest.fn(),
    guardar: jest.fn(),
    distrito: jest.fn(),
  };
  const logic = new EmpresaLogic(
    model as unknown as EmpresaModel,
    {} as SupabaseStorageService,
  );

  beforeEach(() => {
    jest.clearAllMocks();
    model.obtener.mockResolvedValue({ ...empresa });
    model.guardar.mockImplementation((datos: { modoEntregaDirecta: number }) =>
      Promise.resolve({
        ...empresa,
        modo_entrega_directa: datos.modoEntregaDirecta,
      }),
    );
  });

  it('prende la entrega directa y la devuelve como booleano', async () => {
    const r = await logic.guardar(
      { ...dtoBase, modoEntregaDirecta: true },
      7,
      1,
    );
    expect(model.guardar).toHaveBeenCalledWith(
      expect.objectContaining({ modoEntregaDirecta: 1 }),
      7,
      1,
    );
    expect(r).toMatchObject({ modoEntregaDirecta: true });
  });

  it('la apaga y guarda 0', async () => {
    const r = await logic.guardar(
      { ...dtoBase, modoEntregaDirecta: false },
      7,
      1,
    );
    expect(model.guardar).toHaveBeenCalledWith(
      expect.objectContaining({ modoEntregaDirecta: 0 }),
      7,
      1,
    );
    expect(r).toMatchObject({ modoEntregaDirecta: false });
  });

  it('si el cliente no manda el campo conserva lo guardado', async () => {
    model.obtener.mockResolvedValue({ ...empresa, modo_entrega_directa: 1 });
    await logic.guardar({ ...dtoBase }, 7, 1);
    expect(model.guardar).toHaveBeenCalledWith(
      expect.objectContaining({ modoEntregaDirecta: 1 }),
      7,
      1,
    );
  });

  it('al leer la empresa devuelve el modo como booleano', async () => {
    model.obtener.mockResolvedValue({ ...empresa, modo_entrega_directa: 1 });
    await expect(logic.obtener(1)).resolves.toMatchObject({
      modoEntregaDirecta: true,
    });
  });
});
