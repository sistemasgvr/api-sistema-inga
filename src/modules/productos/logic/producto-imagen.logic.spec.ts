import sharp from 'sharp';
import { ProductoImagenLogic } from './producto-imagen.logic';
import { SupabaseStorageService } from '../../../integrations/supabase-storage/supabase-storage.service';

describe('ProductoImagenLogic con Sharp', () => {
  const upload = jest.fn(async (path: string, buffer: Buffer, mime: string, upsert: boolean) => ({ path }));
  const getPublicUrl = jest.fn((path: string) => `https://storage.example/${path}`);
  const remove = jest.fn(async () => undefined);
  const logic = new ProductoImagenLogic({ upload, getPublicUrl, remove } as unknown as SupabaseStorageService);
  const file = (buffer: Buffer) => ({ buffer, originalname: 'foto.jpg', mimetype: 'image/jpeg' }) as Express.Multer.File;
  beforeEach(() => jest.clearAllMocks());

  it('sube WebP real, conserva proporción y limita a 1600 px', async () => {
    const original = await sharp({ create: { width: 2400, height: 1200, channels: 3, background: '#e21b28' } }).png().toBuffer();
    const result = await logic.subir(file(original));
    const [path, buffer, mime, upsert] = upload.mock.calls[0];
    const metadata = await sharp(buffer).metadata();
    expect(metadata.format).toBe('webp');
    expect([metadata.width, metadata.height]).toEqual([1600, 800]);
    expect(buffer.length).toBeLessThan(original.length);
    expect(path).toMatch(/^productos\/prod_.+\.webp$/);
    expect(mime).toBe('image/webp');
    expect(upsert).toBe(false);
    expect(result.url).toBe(`https://storage.example/${path}`);
  });

  it('no amplía imágenes pequeñas y conserva transparencia', async () => {
    const original = await sharp({ create: { width: 32, height: 16, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } } }).png().toBuffer();
    await logic.subir(file(original));
    const metadata = await sharp(upload.mock.calls[0][1]).metadata();
    expect([metadata.width, metadata.height, metadata.hasAlpha]).toEqual([32, 16, true]);
  });

  it('rechaza archivos corruptos y demasiado grandes antes de subir', async () => {
    await expect(logic.subir(file(Buffer.from('no es una imagen')))).rejects.toThrow('No se pudo procesar');
    await expect(logic.subir(file(Buffer.alloc(5 * 1024 * 1024 + 1)))).rejects.toThrow('5 MB');
    await expect(logic.subir()).rejects.toThrow('adjuntar');
    expect(upload).not.toHaveBeenCalled();
  });
});
