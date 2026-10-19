import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import { SupabaseStorageService } from '../../../integrations/supabase-storage/supabase-storage.service';
import { GuardarEmpresaDto } from '../dto/empresa.dto';
import { EmpresaModel, type EmpresaRegistro } from '../models/empresa.model';

/** Medidas del logo en el ticket, en puntos de la impresora (58 mm ≈ 384 puntos de ancho). */
const TICKET_ANCHO = 320;
const TICKET_ALTO = 140;

@Injectable()
export class EmpresaLogic {
  private readonly logger = new Logger(EmpresaLogic.name);

  constructor(
    private readonly model: EmpresaModel,
    private readonly storage: SupabaseStorageService,
  ) {}

  async obtener() {
    const empresa = await this.model.obtener();
    return empresa ? this.respuesta(empresa) : null;
  }

  async guardar(dto: GuardarEmpresaDto, usuario: number) {
    const empresa = await this.model.guardar(
      {
        ruc: dto.ruc,
        razonSocial: dto.razonSocial,
        direccion: dto.direccion || null,
      },
      usuario,
    );
    return this.respuesta(empresa);
  }

  async subirLogo(file: Express.Multer.File | undefined, usuario: number) {
    if (!file?.buffer?.length) {
      throw new BadRequestException('Debes adjuntar un archivo de imagen');
    }
    const empresa = await this.requerida();

    let original: Buffer;
    let ticket: Buffer;
    try {
      const metadata = await sharp(file.buffer).metadata();
      if (!['jpeg', 'png', 'webp'].includes(metadata.format ?? '')) {
        throw new Error('Formato no admitido');
      }
      original = await sharp(file.buffer, { limitInputPixels: 40_000_000 })
        .rotate()
        .resize({
          width: 800,
          height: 800,
          fit: 'inside',
          withoutEnlargement: true,
        })
        .png()
        .toBuffer();
      ticket = await this.logoTicket(original);
    } catch {
      throw new BadRequestException(
        'No se pudo procesar la imagen. Usa un archivo JPG, PNG o WEBP válido.',
      );
    }

    const subida = await this.storage.upload(
      `empresa/logo_${randomUUID()}.png`,
      original,
      'image/png',
      false,
    );
    const actualizada = await this.model.guardarLogo(
      empresa.id,
      this.storage.getPublicUrl(subida.path),
      ticket.toString('base64'),
      usuario,
    );
    await this.borrarArchivo(empresa.logo_url);
    return this.respuesta(actualizada);
  }

  async eliminarLogo(usuario: number) {
    const empresa = await this.requerida();
    const actualizada = await this.model.guardarLogo(
      empresa.id,
      null,
      null,
      usuario,
    );
    await this.borrarArchivo(empresa.logo_url);
    return this.respuesta(actualizada);
  }

  /** Lo que necesita la PC que imprime para el encabezado de los tickets. */
  async datosTicket() {
    const empresa = await this.model.obtener();
    return {
      ruc: empresa?.ruc ?? null,
      razon_social: empresa?.razon_social ?? null,
      direccion: empresa?.direccion ?? null,
      logo: empresa?.logo_ticket ?? null,
    };
  }

  /**
   * Blanco y negro puro: la térmica no imprime grises y así la vista previa
   * coincide con el papel. Se recortan los márgenes vacíos para no gastar papel.
   */
  private async logoTicket(imagen: Buffer) {
    const plano = await sharp(imagen)
      .flatten({ background: '#ffffff' })
      .png()
      .toBuffer();
    let recortado = plano;
    try {
      recortado = await sharp(plano).trim({ threshold: 20 }).png().toBuffer();
    } catch {
      // Imagen de un solo color: no hay bordes que recortar.
    }
    return sharp(recortado)
      .resize({ width: TICKET_ANCHO, height: TICKET_ALTO, fit: 'inside' })
      .grayscale()
      .threshold(160)
      .png({ palette: true, colours: 2 })
      .toBuffer();
  }

  private async requerida() {
    const empresa = await this.model.obtener();
    if (!empresa) {
      throw new NotFoundException(
        'Primero guarda el RUC y la razón social de la empresa',
      );
    }
    return empresa;
  }

  private async borrarArchivo(url: string | null) {
    const ruta = url ? this.storage.extractPathFromPublicUrl(url) : null;
    if (!ruta) return;
    try {
      await this.storage.remove([ruta]);
    } catch (error) {
      // El logo nuevo ya quedó guardado; un archivo huérfano no debe fallar la operación.
      this.logger.warn(
        `No se pudo borrar el logo anterior: ${(error as Error).message}`,
      );
    }
  }

  private respuesta(empresa: EmpresaRegistro) {
    return {
      id: Number(empresa.id),
      ruc: empresa.ruc,
      razonSocial: empresa.razon_social,
      direccion: empresa.direccion,
      logoUrl: empresa.logo_url,
      logoTicket: empresa.logo_ticket
        ? `data:image/png;base64,${empresa.logo_ticket}`
        : null,
    };
  }
}
