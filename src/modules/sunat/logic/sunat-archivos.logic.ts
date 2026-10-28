import {
  Injectable,
  Logger,
  NotFoundException,
  StreamableFile,
} from '@nestjs/common';
import { SupabaseStorageService } from '../../../integrations/supabase-storage/supabase-storage.service';

export interface ArchivoSunat {
  nombre: string;
  contenido: Buffer;
  tipo: string;
}

export const TIPO_ARCHIVO = {
  xml: 'application/xml',
  zip: 'application/zip',
  pdf: 'application/pdf',
} as const;

/** Respuesta HTTP de descarga (XML, CDR o PDF A4). */
export function archivoSunat({ nombre, contenido, tipo }: ArchivoSunat) {
  return new StreamableFile(contenido, {
    type: tipo,
    disposition: `${tipo === TIPO_ARCHIVO.pdf ? 'inline' : 'attachment'}; filename="${nombre}"`,
    length: contenido.length,
  });
}

/** XML, CDR y PDF A4 en Storage: `sunat/<ruc>/<tipo>/<archivo>`. */
@Injectable()
export class SunatArchivosLogic {
  private readonly logger = new Logger(SunatArchivosLogic.name);

  constructor(private readonly storage: SupabaseStorageService) {}

  /** Guarda y devuelve la ruta; si Storage falla devuelve null (el envío ya ocurrió y no se repite). */
  async guardar(ruta: string, contenido: Buffer | string, tipo: string) {
    if (!this.storage.isConfigured()) return null;
    try {
      const datos =
        typeof contenido === 'string'
          ? Buffer.from(contenido, 'utf8')
          : contenido;
      const { path } = await this.storage.upload(ruta, datos, tipo, true);
      return path;
    } catch (error) {
      this.logger.warn(`No se archivó ${ruta}: ${(error as Error).message}`);
      return null;
    }
  }

  async leer(
    ruta: string | null,
    nombre: string,
    tipo: string,
  ): Promise<ArchivoSunat> {
    if (!ruta) throw new NotFoundException(`No hay ${nombre} archivado`);
    return { nombre, contenido: await this.storage.download(ruta), tipo };
  }
}
