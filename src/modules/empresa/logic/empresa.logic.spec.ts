import sharp from 'sharp';
import { EmpresaLogic } from './empresa.logic';
import { EmpresaModel } from '../models/empresa.model';
import { SupabaseStorageService } from '../../../integrations/supabase-storage/supabase-storage.service';

describe('EmpresaLogic · logo', () => {
  const empresa = {
    id: '1',
    ruc: '20000000001',
    razon_social: 'INGA S.A.C.',
    direccion: 'Av. 1',
    logo_url:
      'https://storage.example/object/public/ingastorage/empresa/viejo.png',
    logo_ticket: null,
  };
  const upload = jest.fn(async (path: string) => ({ path }));
  const getPublicUrl = jest.fn(
    (path: string) => `https://storage.example/${path}`,
  );
  const remove = jest.fn(async () => undefined);
  const extractPathFromPublicUrl = jest.fn(() => 'empresa/viejo.png');
  const model = {
    obtener: jest.fn(async () => empresa),
    guardarLogo: jest.fn(
      async (
        _id: string,
        logo_url: string | null,
        logo_ticket: string | null,
      ) => ({ ...empresa, logo_url, logo_ticket }),
    ),
  };
  const logic = new EmpresaLogic(
    model as unknown as EmpresaModel,
    {
      upload,
      getPublicUrl,
      remove,
      extractPathFromPublicUrl,
    } as unknown as SupabaseStorageService,
  );
  const file = (buffer: Buffer) => ({ buffer }) as Express.Multer.File;
  beforeEach(() => jest.clearAllMocks());

  it('genera un logo de ticket en blanco y negro, sin márgenes y dentro del ancho del papel', async () => {
    // Logo negro de 1000x400 con 100 px de margen blanco y transparente alrededor.
    const marca = await sharp({
      create: { width: 1000, height: 400, channels: 4, background: '#000000' },
    })
      .png()
      .toBuffer();
    const original = await sharp({
      create: {
        width: 1200,
        height: 600,
        channels: 4,
        background: { r: 0, g: 0, b: 0, alpha: 0 },
      },
    })
      .composite([{ input: marca, left: 100, top: 100 }])
      .png()
      .toBuffer();
    const result = await logic.subirLogo(file(original), 7, 1);

    const ticket = Buffer.from(model.guardarLogo.mock.calls[0][2]!, 'base64');
    const metadata = await sharp(ticket).metadata();
    expect(metadata.format).toBe('png');
    expect(metadata.width).toBeLessThanOrEqual(320);
    expect(metadata.height).toBeLessThanOrEqual(140);
    expect(metadata.width! / metadata.height!).toBeCloseTo(2.5, 1); // Se recortó el margen.
    const { data } = await sharp(ticket)
      .grayscale()
      .raw()
      .toBuffer({ resolveWithObject: true });
    expect([...new Set(data)].every((v) => v === 0 || v === 255)).toBe(true);

    expect(upload.mock.calls[0][0]).toMatch(/^empresa\/logo_.+\.png$/);
    expect(remove).toHaveBeenCalledWith(['empresa/viejo.png']);
    expect(result.logoTicket).toMatch(/^data:image\/png;base64,/);
  });

  it('rechaza archivos que no son imagen sin subir nada', async () => {
    await expect(
      logic.subirLogo(file(Buffer.from('no es imagen')), 7, 1),
    ).rejects.toThrow('No se pudo procesar');
    await expect(logic.subirLogo(undefined, 7, 1)).rejects.toThrow('adjuntar');
    expect(upload).not.toHaveBeenCalled();
  });
});
