import { BadRequestException, ValidationPipe } from '@nestjs/common';
import { traducirErroresValidacion } from '../helpers/validacion-mensajes.helper';

/** Pipe global: los errores de validación salen en español, con campo y límite. */
export function crearValidationPipe() {
  return new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
    exceptionFactory: (errores) =>
      new BadRequestException(traducirErroresValidacion(errores)),
  });
}
