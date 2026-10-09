import {
  BadRequestException,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import type {
  SupabaseListItem,
  SupabaseSignedUrlResult,
  SupabaseUploadResult,
} from './interfaces/supabase-storage.interface';

@Injectable()
export class SupabaseStorageService {
  private readonly logger = new Logger(SupabaseStorageService.name);
  private readonly client: SupabaseClient | null;
  private readonly bucket: string;

  constructor(private readonly config: ConfigService) {
    const url = this.config.get<string>('SUPABASE_URL')?.trim() ?? '';
    const serviceRoleKey =
      this.config.get<string>('SUPABASE_SERVICE_ROLE_KEY')?.trim() ?? '';
    this.bucket =
      this.config.get<string>('SUPABASE_STORAGE_BUCKET')?.trim() ||
      'ingastorage';

    if (!url || !serviceRoleKey) {
      this.client = null;
      this.logger.warn(
        'Supabase Storage no configurado (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY)',
      );
      return;
    }

    this.client = createClient(url, serviceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });
  }

  isConfigured(): boolean {
    return this.client != null;
  }

  getBucket(): string {
    return this.bucket;
  }

  private requireClient(): SupabaseClient {
    if (!this.client) {
      throw new ServiceUnavailableException(
        'Supabase Storage no está configurado. Define SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY en el .env',
      );
    }
    return this.client;
  }

  async upload(
    path: string,
    body: Buffer | Uint8Array | ArrayBuffer | Blob | File,
    contentType?: string,
    upsert = true,
  ): Promise<SupabaseUploadResult> {
    const client = this.requireClient();
    const cleanPath = path.replace(/^\/+/, '');

    if (!cleanPath) {
      throw new BadRequestException('La ruta del archivo es obligatoria');
    }

    const { data, error } = await client.storage
      .from(this.bucket)
      .upload(cleanPath, body, {
        contentType,
        upsert,
      });

    if (error) {
      throw new BadRequestException(
        `Error al subir archivo a Supabase: ${error.message}`,
      );
    }

    return {
      path: data.path,
      bucket: this.bucket,
      fullPath: data.fullPath,
    };
  }

  getPublicUrl(path: string): string {
    const client = this.requireClient();
    const cleanPath = path.replace(/^\/+/, '');
    const { data } = client.storage.from(this.bucket).getPublicUrl(cleanPath);
    return data.publicUrl;
  }

  /**
   * Recupera la ruta interna del objeto a partir de su URL pública, que es
   * como se guarda la referencia en la base de datos (`pro_producto.imagen_url`).
   *
   * Devuelve `null` si la URL no pertenece a este bucket, para que quien llame
   * pueda descartar la operación en vez de adivinar una ruta.
   */
  extractPathFromPublicUrl(url: string): string | null {
    const cleanUrl = url.trim();
    if (!cleanUrl) return null;

    // /storage/v1/object/public/<bucket>/<ruta...>
    const marker = '/object/public/';
    const indice = cleanUrl.indexOf(marker);
    if (indice === -1) return null;

    const resto = cleanUrl.slice(indice + marker.length);
    const prefijo = `${this.bucket}/`;

    return resto.startsWith(prefijo) ? resto.slice(prefijo.length) : null;
  }

  /**
   * Borra objetos del bucket. No lanza si la ruta está repetida ni si el objeto
   * ya no existe: Supabase responde con éxito en ambos casos.
   */
  async remove(paths: string[]): Promise<void> {
    const cleanPaths = [...new Set(paths.map((p) => p.trim()).filter(Boolean))];

    // Se filtra antes de exigir el cliente: borrar nada no necesita Supabase.
    if (!cleanPaths.length) return;

    const client = this.requireClient();
    const { error } = await client.storage.from(this.bucket).remove(cleanPaths);

    if (error) {
      throw new BadRequestException(
        `Error al eliminar archivos de Supabase: ${error.message}`,
      );
    }
  }
}