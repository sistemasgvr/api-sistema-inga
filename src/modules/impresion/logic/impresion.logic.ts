import {
  BadRequestException,
  ConflictException,
  Injectable,
} from '@nestjs/common';
import { ImpresionModel } from '../models/impresion.model';

@Injectable()
export class ImpresionLogic {
  constructor(private readonly model: ImpresionModel) {}

  tomar(estaciones: number[], propietario: string) {
    return this.model.tomar(estaciones, propietario);
  }

  pendientes(estaciones: number[]) {
    return this.model.pendientes(estaciones);
  }

  async confirmar(
    id: string,
    propietario: string,
    enviado: boolean,
    error?: string,
  ) {
    if (!(await this.model.confirmar(id, propietario, enviado, error))) {
      throw new ConflictException('El trabajo ya no pertenece a este receptor');
    }
    return { confirmado: true };
  }

  async resolver(id: string, enviado: boolean) {
    if (!(await this.model.resolver(id, enviado))) {
      throw new BadRequestException(
        'El trabajo sigue activo o ya fue resuelto. Espera dos minutos si se perdió la conexión.',
      );
    }
    return { actualizado: true };
  }
}
