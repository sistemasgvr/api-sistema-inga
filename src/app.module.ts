import { Module } from '@nestjs/common';
import { DatabaseModule } from './database/database.module';
import databaseConfig from './config/database.config';
import jwtConfig from './config/jwt.config';
import { ConfigModule } from '@nestjs/config';
import { envValidationSchema } from './config/env.validation';
import { LoginModule } from './modules/login/login.module';
import { UsuariosModule } from './modules/usuarios/usuarios.module';
import { RolesModule } from './modules/roles/roles.module';
import { PermisosModule } from './modules/permisos/permisos.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [databaseConfig, jwtConfig],
      validationSchema: envValidationSchema, 
      validationOptions: {
        allowUnknown: true,
        abortEarly: false,
      },
    }),
    LoginModule,
    DatabaseModule,
    UsuariosModule,
    RolesModule,
    PermisosModule,
  ],
  controllers: [],
  providers: [],
})
export class AppModule {}
