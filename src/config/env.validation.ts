import * as Joi from 'joi';

/**
 * Valida las variables de entorno al arrancar la API.
 * Si falta alguna requerida o el formato es inválido, Nest falla con mensaje claro.
 */
export const envValidationSchema = Joi.object({
  NODE_ENV: Joi.string()
    .valid('development', 'production', 'test')
    .default('development'),

  PORT: Joi.number().port().default(3000),

  HTTP_REQUEST_LOGGER_ENABLED: Joi.boolean()
    .truthy('true')
    .falsy('false')
    .default(true),
  HTTP_REQUEST_LOGGER_MAX_BODY_LENGTH: Joi.number()
    .integer()
    .min(0)
    .default(2000),

  /** Preferido: connection string completa (Supabase / Railway / local). */
  DATABASE_URL: Joi.string()
    .uri({ scheme: ['postgres', 'postgresql'] })
    .optional(),

  /** Alternativa si no usas DATABASE_URL. */
  DB_HOST: Joi.string().hostname().when('DATABASE_URL', {
    is: Joi.exist(),
    then: Joi.optional(),
    otherwise: Joi.required(),
  }),
  DB_PORT: Joi.number().port().default(5432),
  DB_USER: Joi.string().when('DATABASE_URL', {
    is: Joi.exist(),
    then: Joi.optional(),
    otherwise: Joi.required(),
  }),
  DB_PASSWORD: Joi.string().allow('').default(''),
  DB_NAME: Joi.string().when('DATABASE_URL', {
    is: Joi.exist(),
    then: Joi.optional(),
    otherwise: Joi.required(),
  }),
  DB_SSL: Joi.boolean().truthy('true').falsy('false').default(false),
  DB_POOL_MAX: Joi.number().integer().min(1).max(100).default(10),
  DB_IDLE_TIMEOUT_MS: Joi.number().integer().min(0).default(30_000),
  DB_CONNECTION_TIMEOUT_MS: Joi.number().integer().min(0).default(10_000),

  JWT_SECRET: Joi.string().min(16).required(),
  JWT_EXPIRES_IN: Joi.string().default('24h'),
})
  .or('DATABASE_URL', 'DB_HOST')
  .messages({
    'object.missing':
      'Debes definir DATABASE_URL o bien DB_HOST + DB_USER + DB_NAME',
  });
