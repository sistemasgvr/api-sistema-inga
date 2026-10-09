import { SupabaseStorageService } from '../../../integrations/supabase-storage/supabase-storage.service';
import { ProductosLogic } from './productos.logic';
import { ProductosModel } from '../models/productos.model';

const BUCKET = 'ingastorage';
const url = (ruta: string) =>
  `https://proyecto.supabase.co/storage/v1/object/public/${BUCKET}/${ruta}`;

describe('ProductosLogic: retiro de la imagen anterior', () => {
  const PREVIA = url('productos/prod_aaa.webp');
  const NUEVA = url('productos/prod_bbb.webp');

  let obtenerPorId: jest.Mock;
  let actualizar: jest.Mock;
  let remove: jest.Mock;
  let extractPathFromPublicUrl: jest.Mock;
  let logic: ProductosLogic;

  // El borrado es fire-and-forget: hay que drenar la cola de microtareas para
  // observar sus efectos.
  const asentar = () => new Promise((resolve) => setImmediate(resolve));

  const construir = (imagenPrevia: string | null) => {
    obtenerPorId.mockResolvedValue({ registro: { id: 1, imagen_url: imagenPrevia } });
    logic = new ProductosLogic(
      { obtenerPorId, actualizar } as unknown as ProductosModel,
      { remove, extractPathFromPublicUrl } as unknown as SupabaseStorageService,
    );
  };

  beforeEach(() => {
    jest.clearAllMocks();
    obtenerPorId = jest.fn();
    actualizar = jest.fn();
    remove = jest.fn(async () => undefined);
    // Reutiliza el método real: la guarda de prefijo depende de él.
    extractPathFromPublicUrl = jest.fn((u: string) => {
      const marker = '/object/public/';
      const i = u.indexOf(marker);
      if (i === -1) return null;
      const resto = u.slice(i + marker.length);
      const prefijo = `${BUCKET}/`;
      return resto.startsWith(prefijo) ? resto.slice(prefijo.length) : null;
    });
  });

  it('borra el objeto anterior cuando la imagen se reemplaza', async () => {
    construir(PREVIA);
    actualizar.mockResolvedValue({ registro: { id: 1, imagen_url: NUEVA } });

    await logic.actualizar(1, { imagen_url: NUEVA });
    await asentar();

    expect(remove).toHaveBeenCalledWith(['productos/prod_aaa.webp']);
  });

  it('borra el objeto anterior cuando el usuario quita la imagen', async () => {
    construir(PREVIA);
    // El SQL convierte '' en NULL, así que la respuesta llega con null.
    actualizar.mockResolvedValue({ registro: { id: 1, imagen_url: null } });

    await logic.actualizar(1, { imagen_url: '' });
    await asentar();

    expect(remove).toHaveBeenCalledWith(['productos/prod_aaa.webp']);
  });

  it('no borra nada si la imagen no cambió', async () => {
    construir(PREVIA);
    actualizar.mockResolvedValue({ registro: { id: 1, imagen_url: PREVIA } });

    await logic.actualizar(1, { nombre: 'Lomo Saltado' });
    await asentar();

    expect(remove).not.toHaveBeenCalled();
  });

  it('no borra nada si el producto nunca tuvo imagen', async () => {
    construir(null);
    actualizar.mockResolvedValue({ registro: { id: 1, imagen_url: NUEVA } });

    await logic.actualizar(1, { imagen_url: NUEVA });
    await asentar();

    expect(remove).not.toHaveBeenCalled();
  });

  it('conserva el guardado aunque Supabase falle al borrar', async () => {
    construir(PREVIA);
    actualizar.mockResolvedValue({ registro: { id: 1, imagen_url: NUEVA } });
    remove.mockRejectedValue(new Error('bucket inaccesible'));

    const resultado = await logic.actualizar(1, { imagen_url: NUEVA });
    await asentar();

    expect(resultado).toEqual({ id: 1, imagen_url: NUEVA });
  });

  it('no borra si la URL previa apunta fuera de la carpeta productos', async () => {
    // `imagen_url` es texto libre: una URL ajena no debe ser capaz de borrar.
    const ajena = url('facturacion/recibo_2026.pdf');
    construir(ajena);
    actualizar.mockResolvedValue({ registro: { id: 1, imagen_url: NUEVA } });

    await logic.actualizar(1, { imagen_url: NUEVA });
    await asentar();

    expect(remove).not.toHaveBeenCalled();
  });

  it('no borra si la URL no pertenece a este bucket', async () => {
    const otroBucket =
      'https://otro.supabase.co/storage/v1/object/public/otro/productos/prod_aaa.webp';
    construir(otroBucket);
    actualizar.mockResolvedValue({ registro: { id: 1, imagen_url: NUEVA } });

    await logic.actualizar(1, { imagen_url: NUEVA });
    await asentar();

    expect(remove).not.toHaveBeenCalled();
  });

  it('guarda aunque no se pueda leer la imagen previa', async () => {
    obtenerPorId.mockRejectedValue(new Error('producto no existe'));
    actualizar.mockResolvedValue({ registro: { id: 1, imagen_url: NUEVA } });
    logic = new ProductosLogic(
      { obtenerPorId, actualizar } as unknown as ProductosModel,
      { remove, extractPathFromPublicUrl } as unknown as SupabaseStorageService,
    );

    const resultado = await logic.actualizar(1, { imagen_url: NUEVA });
    await asentar();

    expect(resultado).toEqual({ id: 1, imagen_url: NUEVA });
    expect(remove).not.toHaveBeenCalled();
  });
});