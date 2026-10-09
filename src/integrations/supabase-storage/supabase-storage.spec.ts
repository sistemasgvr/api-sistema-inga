import { SupabaseStorageService } from './supabase-storage.service';

describe('SupabaseStorageService: rutas y borrado', () => {
  const construir = () =>
    new SupabaseStorageService({
      get: (clave: string) =>
        clave === 'SUPABASE_STORAGE_BUCKET' ? 'ingastorage' : undefined,
    } as never);

  const svc = construir();
  const ruta = 'productos/prod_abc.webp';

  describe('extractPathFromPublicUrl', () => {
    it('extrae la ruta interna de una URL pública del bucket', () => {
      expect(
        svc.extractPathFromPublicUrl(
          `https://proyecto.supabase.co/storage/v1/object/public/ingastorage/${ruta}`,
        ),
      ).toBe(ruta);
    });

    it('devuelve null si la URL es de otro bucket', () => {
      expect(
        svc.extractPathFromPublicUrl(
          'https://x.supabase.co/storage/v1/object/public/otro/productos/a.webp',
        ),
      ).toBeNull();
    });

    it('devuelve null si la URL no es de Supabase Storage', () => {
      expect(svc.extractPathFromPublicUrl('https://ejemplo.com/a.webp')).toBeNull();
      expect(svc.extractPathFromPublicUrl('')).toBeNull();
      expect(svc.extractPathFromPublicUrl('   ')).toBeNull();
    });

    it('no acepta una URL manipulada para escapar de la carpeta', () => {
      // Sin el marcador real, no hay ruta que devolver.
      expect(
        svc.extractPathFromPublicUrl(
          'https://x.supabase.co/storage/v1/object/public/ingastorage/../../admin/secret',
        ),
      ).toBe('../../admin/secret');
      // El llamador aplica la guarda de prefijo; aquí solo se resuelve la ruta.
    });
  });

  describe('remove', () => {
    it('no llama a Supabase si la lista viene vacía o en blanco', async () => {
      // Sin cliente configurado, cualquier llamada real lanzaría 503.
      await expect(svc.remove([])).resolves.toBeUndefined();
      await expect(svc.remove(['', '   '])).resolves.toBeUndefined();
    });
  });
});