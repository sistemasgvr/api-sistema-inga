import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const raiz = join(__dirname, '..', '..', 'database_sql', 'funciones', 'productos', 'productos');
const leer = (archivo: string) => readFileSync(join(raiz, archivo), 'utf8');

const listar = leer('pro_listar_productos.sql');
const obtener = leer('pro_obtener_producto.sql');

/**
 * Columnas que la función proyecta realmente.
 *
 * `pro_listar_productos` tiene varios `SELECT` (los de conteo), así que el
 * ancla debe ser el `json_agg(row_to_json(t))` y no el primer `SELECT`.
 * `pro_obtener_producto` no usa json_agg: usa `SELECT ... INTO ... FROM (`.
 *
 * En ambos casos se lee desde el `SELECT` de columnas hasta el cierre de la
 * subconsulta, para no capturar los campos que solo salen en el filtro.
 *
 * Tolera CRLF: los archivos se guardan con `\r\n` en Windows.
 */
const proyectadas = (sql: string): Set<string> => {
  const columnas = new Set<string>();

  // Acepta `columna`, `p.columna`, `tp.columna`, `sc.nombre AS nombre_subcategoria`.
  // El alias de tabla es cualquiera: los JOIN aportan `tp.`, `sc.`, `um.`, `e.`...
  // Cuando hay `AS`, lo que viaja en el JSON es el alias, no la columna.
  const COLUMNA = /^\s*(?:\w+\.)?(\w+)\s*(?:AS\s+(\w+)\s*)?,?\s*$/;
  const anadir = (m: RegExpMatchArray) =>
    columnas.add(m[2] ?? m[1]);

  if (sql.includes('json_agg(row_to_json(t))')) {
    const bloque = sql.slice(sql.indexOf('json_agg(row_to_json(t))'));
    for (const linea of bloque.split('\n')) {
      const m = linea.replace(/\r$/, '').match(COLUMNA);
      if (m) anadir(m);
    }
    return columnas;
  }

  // Forma `SELECT ... INTO v_registro FROM ( ... ) t;`
  const desde = sql.indexOf('INTO v_registro');
  const bloque = desde === -1 ? sql : sql.slice(sql.lastIndexOf('SELECT', desde));
  for (const linea of bloque.split('\n')) {
    if (/^\s*\)\s*t\s*;?\s*$/.test(linea)) break;
    const m = linea.replace(/\r$/, '').match(COLUMNA);
    if (m) anadir(m);
  }
  return columnas;
};

describe('Contrato del listado de productos', () => {
  const delListado = proyectadas(listar);
  const delDetalle = proyectadas(obtener);

  it('el extractor encuentra columnas en ambos archivos', () => {
    // Guarda contra un test que pasa comparando dos conjuntos vacíos.
    expect(delListado.size).toBeGreaterThan(15);
    expect(delDetalle.size).toBeGreaterThan(15);
    expect(delListado.has('id')).toBe(true);
    expect(delDetalle.has('id')).toBe(true);
  });

  it('proyecta todo campo editable que pro_obtener_producto proyecta', () => {
    // El modal se inicializa con campos del producto. Si el listado omite uno,
    // `Boolean(undefined)` o `|| ""` lo convierten en valor falso y el
    // guardado sobrescribe lo que ya estaba en la base.
    //
    // Se exceptúan los campos de auditoría: el listado no tiene por qué
    // arrastrarlos en cada fila.
    const soloAuditoria = /^(id_usuario_|nombre_usuario_)/;
    const faltantes = [...delDetalle].filter(
      (c) => !delListado.has(c) && !soloAuditoria.test(c),
    );
    expect(faltantes).toEqual([]);
  });

  it('incluye los campos que el modal reseteaba a un valor falso', () => {
    // Regresión concreta: sin afecto_igv en el listado, editar un producto
    // guardaba afecto_igv=false y borraba el valor real.
    for (const campo of ['afecto_igv', 'descripcion', 'tiempo_prep_min']) {
      expect(delListado.has(campo)).toBe(true);
    }
  });

  it('incluye los flags del tipo de producto que usa la tabla', () => {
    // Regresión concreta: sin `requiere_receta` el botón "Gestionar receta"
    // desaparecía, porque la tabla lo decide con Boolean(prod.requiere_receta).
    for (const campo of [
      'nombre_tipo_producto',
      'permite_venta',
      'requiere_receta',
      'requiere_estacion',
      'permite_stock_inicial',
    ]) {
      expect(delListado.has(campo)).toBe(true);
    }
  });

  it('une pro_tipo_producto si proyecta columnas de ese alias', () => {
    // Proyectar `tp.*` sin el JOIN no compila en PostgreSQL.
    const proyectaTp = [...delListado].some((c) =>
      /^(nombre_tipo_producto|permite_venta|requiere_receta|requiere_estacion|permite_stock_inicial)$/.test(
        c,
      ),
    );
    if (proyectaTp) {
      expect(listar).toMatch(/JOIN\s+pro_tipo_producto\s+tp\s+ON\s+tp\.id\s*=/);
    }
  });

  it('no usa un campo en el filtro de búsqueda sin proyectarlo', () => {
    // descripcion aparecía en el WHERE pero no en el SELECT.
    expect(listar).toMatch(/p\.descripcion,\s*$/m);
  });
});

describe('Limpieza de campos en pro_actualizar_producto', () => {
  const actualizar = leer('pro_actualizar_producto.sql');

  it('permite vaciar imagen y descripción', () => {
    // COALESCE puro hace imposible limpiarlos: mandarlos llega como NULL.
    for (const campo of ['imagen_url', 'descripcion']) {
      expect(actualizar).toMatch(
        new RegExp(`${campo} = CASE WHEN p_${campo} = '' THEN NULL`),
      );
    }
  });
});