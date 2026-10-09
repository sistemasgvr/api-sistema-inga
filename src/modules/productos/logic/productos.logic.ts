import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import {
  mapActivateResult,
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { SupabaseStorageService } from '../../../integrations/supabase-storage/supabase-storage.service';
import { CreateProductoDto, FiltroProductosDto, UpdateProductoDto } from '../dto/productos.dto';
import { ProductosModel } from '../models/productos.model';

// Prefijo bajo el que este módulo escribe. Nada fuera de él se borra jamás.
const PREFIJO_IMAGENES = 'productos/';

@Injectable()
export class ProductosLogic {
  private readonly logger = new Logger(ProductosLogic.name);

  constructor(
    private readonly productosModel: ProductosModel,
    private readonly storage: SupabaseStorageService,
  ) {}

  async listar(filtros: FiltroProductosDto) {
    const result = await this.productosModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.productosModel.obtenerPorId(id);
    return mapSingleResult(result, `Producto con ID ${id} no encontrado`);
  }

  async listarUnidadesMedida() {
    return await this.productosModel.listarUnidadesMedida();
  }

  async crear(dto: CreateProductoDto) {
    try {
      const result = await this.productosModel.crear(dto);
      return mapSingleResult(result, 'No se pudo crear el producto');
    } catch (error) {
      if ((error as {code?:string}).code === 'P0001') throw new BadRequestException((error as Error).message);
      throw error;
    }
  }

  async actualizar(id: number, dto: UpdateProductoDto) {
    // Se lee la imagen previa porque, tras guardar, es la única forma de saber
    // cuál objeto quedó huérfano. Una consulta extra a cambio de no llenar el
    // bucket en cada reemplazo.
    const previa = await this.imagenActual(id);

    const result = await this.productosModel.actualizar(id, dto);
    const actualizado = mapSingleResult(result, `Producto con ID ${id} no encontrado`);

    // La base ya apunta a la nueva imagen: en este punto el objeto anterior solo
    // es basura y nunca debe bloquear un guardado correcto.
    const nueva = (actualizado as { imagen_url?: string | null })?.imagen_url ?? null;
    if (previa && previa !== nueva) {
      void this.retirarImagen(previa);
    }

    return actualizado;
  }

  /** Devuelve la `imagen_url` vigente, o `null` si el producto no existe. */
  private async imagenActual(id: number): Promise<string | null> {
    try {
      const resultado = await this.productosModel.obtenerPorId(id);
      const registro = resultado?.registro as { imagen_url?: string | null } | null;
      return registro?.imagen_url?.trim() || null;
    } catch (error) {
      // Si no se puede leer el estado previo se sigue guardando: es preferible
      // dejar un huérfano a que el usuario no pueda editar el producto.
      this.logger.warn(
        `No se pudo leer la imagen previa del producto ${id}`,
        error as Error,
      );
      return null;
    }
  }

  /**
   * Borra el objeto de una imagen que ya no referencia ningún producto.
   *
   * Es fire-and-forget a propósito: un fallo de Supabase no debe reportarse como
   * error del guardado, porque la base de datos ya quedó correcta.
   */
  private async retirarImagen(url: string): Promise<void> {
    try {
      const ruta = this.storage.extractPathFromPublicUrl(url);

      // `imagen_url` es texto libre en la base: si la URL apunta a otro bucket o
      // a otra carpeta, se descarta en lugar de intentar borrar nada.
      if (!ruta || !ruta.startsWith(PREFIJO_IMAGENES)) {
        this.logger.warn(
          `Se omite el borrado de una imagen fuera de ${PREFIJO_IMAGENES}: ${url}`,
        );
        return;
      }

      await this.storage.remove([ruta]);
    } catch (error) {
      this.logger.warn(
        `No se pudo borrar la imagen anterior "${url}". Quedará como huérfana en el bucket.`,
        error as Error,
      );
    }
  }

  async toggleDisponibilidad(id: number, idUsuarioAuditoria?: number) {
    const result = await this.productosModel.toggleDisponibilidad(id, idUsuarioAuditoria);
    return mapSingleResult(result, `Producto con ID ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.productosModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Producto con ID ${id} no encontrado o tiene stock activo`);
  }

  async activar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.productosModel.activar(id, idUsuarioAuditoria);
    return mapActivateResult(result, `Producto con ID ${id} no encontrado o ya activo`);
  }
}