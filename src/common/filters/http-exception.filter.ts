import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { ApiErrorResponse } from '../interfaces/api-response.interface';
import { MONTO_MAXIMO } from '../constants/limites';
import { formatearNumero } from '../helpers/validacion-mensajes.helper';

interface ErrorCause {
  message: string;
  code?: string;
  detail?: string;
  table?: string;
  constraint?: string;
}

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const request = ctx.getRequest<Request>();
    const response = ctx.getResponse<Response>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = 'Error interno del servidor';
    let errors: string[] | null = null;

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const exceptionResponse = exception.getResponse();

      if (typeof exceptionResponse === 'string') {
        message = exceptionResponse;
      } else if (typeof exceptionResponse === 'object') {
        const res = exceptionResponse as Record<string, unknown>;
        const rawMessage = res.message;

        if (Array.isArray(rawMessage)) {
          errors = rawMessage as string[];
          // El front muestra `message`: va el detalle, no un genérico.
          message = errors.length ? errors.join(' ') : 'Revisa los datos ingresados.';
        } else if (typeof rawMessage === 'string') {
          message = rawMessage;
        }
      }
    } else {
      const errorDatos = this.getDataError(exception);
      if (errorDatos) {
        status = HttpStatus.BAD_REQUEST;
        message = errorDatos;
      }
    }

    if (status >= HttpStatus.INTERNAL_SERVER_ERROR) {
      const cause = this.getErrorCause(exception);
      response.locals.errorCause = cause;
      this.logUnhandledException(cause, exception, request);
    }

    const body: ApiErrorResponse = {
      success: false,
      message,
      data: null,
      errors,
      statusCode: status,
    };

    response.status(status).json(body);
  }

  /**
   * Errores de PostgreSQL causados por el dato que envió el usuario. Los DTO ya
   * ponen topes; esto evita un "Error interno" si algún campo se escapa.
   */
  private getDataError(exception: unknown): string | null {
    const code = (exception as { code?: unknown } | null)?.code;
    switch (code) {
      case '22003':
        return `Uno de los montos o cantidades supera el máximo permitido (${formatearNumero(MONTO_MAXIMO)}).`;
      case '22001':
        return 'Uno de los textos supera la longitud permitida.';
      default:
        return null;
    }
  }

  private getErrorCause(exception: unknown): ErrorCause {
    if (exception instanceof Error) {
      const dbError = exception as Error & {
        code?: string;
        detail?: string;
        table?: string;
        constraint?: string;
      };

      return {
        message: exception.message,
        code: dbError.code,
        detail: dbError.detail,
        table: dbError.table,
        constraint: dbError.constraint,
      };
    }

    return {
      message: JSON.stringify(exception),
    };
  }

  private logUnhandledException(
    cause: ErrorCause,
    exception: unknown,
    request: Request,
  ) {
    const method = request.method;
    const url = request.originalUrl;

    if (exception instanceof Error) {
      this.logger.error(
        `${method} ${url} failed: ${cause.message}` +
          `${cause.code ? ` | code=${cause.code}` : ''}` +
          `${cause.detail ? ` | detail=${cause.detail}` : ''}` +
          `${cause.table ? ` | table=${cause.table}` : ''}` +
          `${cause.constraint ? ` | constraint=${cause.constraint}` : ''}`,
        exception.stack,
      );
      return;
    }

    this.logger.error(`${method} ${url} failed: ${cause.message}`);
  }
}
