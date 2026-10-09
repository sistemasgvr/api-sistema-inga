import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const raiz = join(__dirname, '..', '..', 'database_sql');
const leer = (r: string) => readFileSync(join(raiz, r), 'utf8');

const obtener = leer('funciones/productos/productos-recetas-insumos/pro_obtener_receta.sql');
const costo = leer('funciones/productos/productos-recetas-insumos/pro_recalcular_costo_receta.sql');
const unitario = leer(
  'funciones/productos/productos-recetas-insumos/pro_costo_unitario_insumo.sql',
);
const recalcular = leer('utilidades/recalcular_costos_receta.sql');

describe('Valorizacion de recetas', () => {
  describe('pro_costo_unitario_insumo', () => {
    it('distingue plato con receta de insumo crudo', () => {
      expect(unitario).toMatch(/r\.vigente/);
      expect(unitario).toMatch(/costo_receta_calculado/);
      expect(unitario).toMatch(/costo_promedio/);
    });

    it('usa subconsultas y no un JOIN que pueda duplicar filas', () => {
      // Un producto con stock en varios almacenes duplicaría el insumo.
      expect(unitario).not.toMatch(/JOIN\s+alm_producto_stock/i);
    });

    it('devuelve 0 en vez de null cuando no hay costo', () => {
      expect(unitario).toMatch(/RETURN COALESCE\(v_costo, 0\)/);
    });
  });

  describe('pro_recalcular_costo_receta', () => {
    it('delega el costo a la función compartida', () => {
      // Si cada uno resolviera el costo por su cuenta, el detalle por insumo no
      // sumaría el total que se muestra.
      expect(costo).toMatch(/pro_costo_unitario_insumo\(ri\.id_producto_insumo\)/);
      expect(costo).not.toMatch(/aps\.costo_promedio/);
    });
  });

  describe('pro_obtener_receta', () => {
    it('expone el costo total de la receta', () => {
      expect(obtener).toMatch(/costo_receta_calculado AS costo_total_calculado/);
    });

    it('expone el costo unitario y el subtotal de cada insumo', () => {
      expect(obtener).toMatch(/costo_unitario_estimado/);
      expect(obtener).toMatch(/monto_subtotal/);
    });

    it('el subtotal aplica cantidad y merma, igual que el total', () => {
      expect(obtener).toMatch(
        /ri\.cantidad \* \(1 \+ ri\.porcentaje_merma \/ 100\.0\)/,
      );
    });
  });

  describe('Script de recalculo', () => {
    it('recorre las recetas vigentes', () => {
      expect(recalcular).toMatch(/r\.estado = 1 AND r\.vigente/);
      expect(recalcular).toMatch(/PERFORM pro_recalcular_costo_receta/);
    });

    it('es idempotente: correrlo dos veces da el mismo resultado', () => {
      expect(recalcular).not.toMatch(/INSERT|UPDATE|DELETE/i);
    });
  });
});