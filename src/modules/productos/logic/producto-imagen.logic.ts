import { BadRequestException, Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import { SupabaseStorageService } from '../../../integrations/supabase-storage/supabase-storage.service';

@Injectable()
export class ProductoImagenLogic {
  constructor(private readonly storage: SupabaseStorageService) {}

  async subir(file?: Express.Multer.File) {
    if (!file?.buffer?.length) {
      throw new BadRequestException('Debes adjuntar un archivo de imagen');
    }
    if (file.buffer.length > 5 * 1024 * 1024) {
      throw new BadRequestException('La imagen no puede superar los 5 MB.');
    }

    let buffer: Buffer;
    try {
      const image = sharp(file.buffer, { limitInputPixels: 40_000_000 });
      const metadata = await image.metadata();
      if (!['jpeg', 'png', 'webp'].includes(metadata.format ?? '')) {
        throw new Error('Formato no admitido');
      }
      buffer = await image.rotate()
        .resize({ width: 1600, height: 1600, fit: 'inside', withoutEnlargement: true })
        .webp({ quality: 80 })
        .toBuffer();
    } catch {
      throw new BadRequestException('No se pudo procesar la imagen. Usa un archivo JPG, PNG o WEBP válido.');
    }

    const result = await this.storage.upload(
      `productos/prod_${randomUUID()}.webp`, buffer, 'image/webp', false,
    );
    return { url: this.storage.getPublicUrl(result.path) };
  }
}
