import { Module } from '@nestjs/common';
import { ProductosController } from './controllers/productos.controller';
import { ProductosLogic } from './logic/productos.logic';
import { ProductosModel } from './models/productos.model';
import { ProductoImagenLogic } from './logic/producto-imagen.logic';

@Module({
  controllers: [ProductosController],
  providers: [ProductosLogic, ProductosModel, ProductoImagenLogic],
  exports: [ProductosLogic],
})
export class ProductosModule {}
