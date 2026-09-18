import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { DatabaseModule } from './database/database.module';
import databaseConfig from './config/database.config';
import jwtConfig from './config/jwt.config';
import { ConfigModule } from '@nestjs/config';
import { envValidationSchema } from './config/env.validation';
import { LoginModule } from './modules/login/login.module';
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
import { PersonasModule } from './modules/personas/personas.module';
import { ConveniosModule } from './modules/convenios/convenios.module';
import { CajasModule } from './modules/cajas/cajas.module';
import { TurnosModule } from './modules/turnos/turnos.module';
import { PlanillaModule } from './modules/planilla/planilla.module';
import { GastosAdministrativosModule } from './modules/gastos-administrativos/gastos-administrativos.module';
import { CuentasPorCobrarModule } from './modules/cuentas-por-cobrar/cuentas-por-cobrar.module';
import { CuentasPorPagarModule } from './modules/cuentas-por-pagar/cuentas-por-pagar.module';
import { GastosDiariosModule } from './modules/gastos-diarios/gastos-diarios.module';

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
    CategoriasProductoModule,
    SubCategoriasProductoModule,
    ProductosModule,
    RecetasProductoModule,
    AdicionalesProductoModule,
    AlmacenesModule,
    EstacionesModule,
    SucursalesModule,
    // Maestro de personas: lo dejo al final para que agregar módulos nuevos
    // siempre sea añadir una línea acá abajo y el conflicto de merge sea mínimo.
    ConveniosModule,
    PersonasModule,
    // M11 - Caja y turnos.
    CajasModule,
    TurnosModule,
    // M17 - Planilla.
    PlanillaModule,
    // M16 - Gastos administrativos.
    GastosAdministrativosModule,
    // M15 - Cuentas por pagar a proveedores.
    CuentasPorPagarModule,
    CuentasPorCobrarModule,
    // M14 - Gastos diarios operativos.
    GastosDiariosModule,
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
