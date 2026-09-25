import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { DatabaseModule } from './database/database.module';
import databaseConfig from './config/database.config';
import jwtConfig from './config/jwt.config';
import { ConfigModule } from '@nestjs/config';
import { envValidationSchema } from './config/env.validation';
import { LoginModule } from './modules/login/login.module';
import { GeneralListasModule } from './modules/general/general-listas.module';
import { UsuariosModule } from './modules/usuarios/usuarios.module';
import { RolesModule } from './modules/roles/roles.module';
import { PermisosModule } from './modules/permisos/permisos.module';
import { CategoriasProductoModule } from './modules/categorias-producto/categorias-producto.module';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { SubCategoriasProductoModule } from './modules/subcategorias-producto/subcategorias-producto.module';
import { RecetasProductoModule } from './modules/recetas-producto/recetas-producto.module';
import { AdicionalesProductoModule } from './modules/adicionales-producto/adicionales-producto.module';
import { ProductosModule } from './modules/productos/productos.module';
import { AlmacenesModule } from './modules/almacenes/almacenes.module';
import { EstacionesModule } from './modules/estaciones/estaciones.module';
import { SucursalesModule } from './modules/sucursales/sucursales.module';
import { SupabaseStorageModule } from './integrations/supabase-storage/supabase-storage.module';

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
    SupabaseStorageModule,
    GeneralListasModule,
    UsuariosModule,
    RolesModule,
    PermisosModule,
    CategoriasProductoModule,
    SubCategoriasProductoModule,
    RecetasProductoModule,
    ProductosModule,
    AdicionalesProductoModule,
    AlmacenesModule,
    EstacionesModule,
    SucursalesModule
  ],
  controllers: [],
  providers: [
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
  ],
})
export class AppModule {}
