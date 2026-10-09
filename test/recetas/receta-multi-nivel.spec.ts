import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const raiz = join(__dirname, '..', '..', 'database_sql', 'funciones', 'productos');
const leer = (ruta: string) => readFileSync(join(raiz, ruta), 'utf8');

describe('Recetario multi-nivel: estructura', () => {
  const guardar = leer('productos-recetas-insumos/pro_guardar_receta_insumo.sql');
  const costo = leer('productos-recetas-insumos/pro_recalcular_costo_receta.sql');
  const listar = leer('productos-recetas-insumos/pro_listar_insumos_procesados.sql');

  describe('control de ciclos', () => {
    it('usa un CTE recursivo para subir por los ancestros', () => {
      expect(guardar).toMatch(/WITH\s+RECURSIVE/i);
      expect(guardar).toMatch(/ancestros/i);
    });

    it('rechaza que un producto sea insumo de sí mismo', () => {
      expect(guardar).toMatch(
        /IF\s+p_id_producto_insumo\s*=\s*v_id_producto_receta\s+THEN/i,
      );
      expect(guardar).toMatch(/no puede ser insumo de su propia receta/i);
    });

    it('limita la profundidad para que el propio control termine', () => {
      // Sin tope, un grafo ya corrupto en la base colgaría la consulta.
      expect(guardar).toMatch(/nivel\s*<\s*\d+/);
    });

    it('el mensaje nombra la cadena para que el usuario sepa qué corregir', () => {
      expect(guardar).toMatch(/ciclo/i);
    });
  });

  describe('costo', () => {
    it('usa el costo del sub-plato cuando el insumo tiene receta', () => {
      expect(costo).toMatch(/costo_receta_calculado/);
      expect(costo).toMatch(/EXISTS\s*\(\s*SELECT 1 FROM pro_receta/i);
    });

    it('usa el costo promedio para un insumo crudo', () => {
      expect(costo).toMatch(/aps\.costo_promedio/);
    });

    it('propaga el cambio hacia las recetas que contienen al producto', () => {
      // Si sube el costo del filete, el barco no debe quedar con el valor viejo.
      expect(costo).toMatch(/id_producto_insumo\s*=\s*v_id_producto/);
      expect(costo).toMatch(/PERFORM\s+pro_recalcular_costo_receta\s*\(\s*v_padre/i);
    });

    it('acota la recursión de la cascada', () => {
      expect(costo).toMatch(/p_profundidad\s*>=\s*\d+/);
    });

    it('elimina las firmas anteriores antes de crearse', () => {
      // Sin el DROP, CREATE OR REPLACE con otra firma crea una sobrecarga y los
      // llamadores de un solo argumento siguen resolviendo a la versión vieja,
      // sin cascada: el fallo sería silencioso.
      const drop1 = costo.indexOf(
        'DROP FUNCTION IF EXISTS pro_recalcular_costo_receta(BIGINT);',
      );
      const drop2 = costo.indexOf(
        'DROP FUNCTION IF EXISTS pro_recalcular_costo_receta(BIGINT, INTEGER);',
      );
      const create = costo.indexOf('CREATE OR REPLACE FUNCTION pro_recalcular_costo_receta');

      expect(drop1).toBeGreaterThanOrEqual(0);
      expect(drop2).toBeGreaterThanOrEqual(0);
      expect(drop1).toBeLessThan(create);
      expect(drop2).toBeLessThan(create);
    });

    it('resuelve el costo con subconsulta escalar, no con un JOIN que duplique filas', () => {
      // Un producto puede tener stock en varios almacenes: un LEFT JOIN
      // multiplicaría la fila del insumo y inflaría la suma.
      expect(costo).toMatch(/SELECT\s+aps\.costo_promedio[\s\S]*?LIMIT\s+1/i);
      expect(costo).toMatch(/aps\.id_almacen\s*=\s*p\.id_almacen_stock/);
      expect(costo).not.toMatch(/LEFT JOIN\s+alm_producto_stock/i);
    });
  });

  describe('selector de insumos', () => {
    it('ya no restringe a un único tipo de producto', () => {
      // La restricción a tipo 2 impedía usar un plato como componente.
      expect(listar).not.toMatch(/p\.tipo_producto\s*=\s*2/);
    });

    it('exige controla_stock, que es lo que el motor necesita para apartar', () => {
      expect(listar).toMatch(/p\.controla_stock/);
    });

    it('acepta los filtros de tipo, categoría y subcategoría', () => {
      for (const filtro of [
        'p_id_tipo_producto',
        'p_id_categoria',
        'p_id_subcategoria',
      ]) {
        expect(listar).toMatch(new RegExp(filtro));
      }
    });

    it('informa si el producto tiene receta propia para distinguirlo en la UI', () => {
      expect(listar).toMatch(/tiene_receta/);
    });

    it('elimina la firma anterior de un solo argumento', () => {
      // Igual que pro_recalcular_costo_receta: con otra firma, CREATE OR REPLACE
      // crea una sobrecarga y la versión vieja sigue viva junto a la nueva.
      const drop = listar.indexOf(
        'DROP FUNCTION IF EXISTS pro_listar_insumos_procesados(VARCHAR);',
      );
      const create = listar.indexOf(
        'CREATE OR REPLACE FUNCTION pro_listar_insumos_procesados',
      );
      expect(drop).toBeGreaterThanOrEqual(0);
      expect(drop).toBeLessThan(create);
    });

    it('informa si un sub-plato tiene grupos de sustitución', () => {
      // La UI avisa que ese sub-plato solo podrá producirse por pedido, porque
      // prod_preparar rechaza la producción anticipada en ese caso.
      expect(listar).toMatch(/tiene_grupos_sustitucion/);
      expect(listar).toMatch(/grupo_sustitucion\s+IS\s+NOT\s+NULL/i);
    });

    it('filtra la categoría por el join, no por una columna inexistente', () => {
      // pro_producto no tiene id_categoria: viene de pro_subcategoria.
      expect(listar).toMatch(/sc\.id_categoria/);
      expect(listar).not.toMatch(/\bp\.id_categoria\b/);
    });
  });
});