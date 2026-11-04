import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const raiz = join(__dirname, '..', '..', 'database_sql');
const leer = (ruta: string) => readFileSync(join(raiz, ruta), 'utf8');

/**
 * Entrega directa (gen_empresa.modo_entrega_directa = 1): el plato queda "por
 * entregar" al comandar, cocina solo mira y la entrega descuenta lo preparado o,
 * si falta, los insumos apartados. Con el modo apagado todo sigue como antes.
 */
describe('Entrega directa · estructura SQL', () => {
  const migracion = leer('migraciones/20261107_modo_entrega_directa.sql');
  const comandar = leer('funciones/pedidos/ven_pedido_comandar.sql');
  const entregar = leer('funciones/pedidos/ven_pedido_entregar.sql');
  const preparacion = leer('funciones/pedidos/ven_pedido_preparacion.sql');
  const obtenerEmpresa = leer(
    'funciones/general/empresa/gen_obtener_empresa.sql',
  );
  const guardarEmpresa = leer(
    'funciones/general/empresa/gen_guardar_empresa.sql',
  );
  const obtenerPedido = leer('funciones/pedidos/ven_obtener_pedido.sql');
  const anularItem = leer('funciones/pedidos/ven_pedido_anular_item.sql');

  it('guarda el modo por empresa, apagado por defecto', () => {
    expect(migracion).toMatch(
      /ADD COLUMN IF NOT EXISTS modo_entrega_directa SMALLINT NOT NULL DEFAULT 0/i,
    );
    expect(migracion).toMatch(/CHECK \(modo_entrega_directa IN \(0, 1\)\)/i);
  });

  it('la empresa expone y guarda el modo', () => {
    expect(obtenerEmpresa).toMatch(
      /'modo_entrega_directa',\s*e\.modo_entrega_directa/,
    );
    // Si el front no lo manda, se conserva el valor actual.
    expect(guardarEmpresa).toMatch(/modo_entrega_directa = COALESCE\(/);
  });

  it('al comandar deja el plato por entregar solo en modo directo', () => {
    expect(comandar).toMatch(/modo_entrega_directa/);
    expect(comandar).toMatch(
      /estado_preparacion = CASE WHEN v_directo THEN 4 ELSE 2 END/,
    );
  });

  it('la entrega usa lo preparado y, si falta, los insumos apartados', () => {
    expect(entregar).toMatch(/usado:=LEAST\(n,d\.cantidad_reservada\)/);
    expect(entregar).toMatch(
      /insumos:=ven_liberar_insumos\(p_item,resto,p_usuario\)/,
    );
    // La reserva de producto terminado se libera antes de aplicarla, igual que antes.
    expect(entregar).toMatch(/stock_reservado=stock_reservado-usado/);
  });

  it('sin modo directo la entrega sigue exigiendo el plato preparado', () => {
    expect(entregar).toMatch(
      /IF NOT v_directo THEN RAISE EXCEPTION 'Faltan platos preparados o productos disponibles'/,
    );
  });

  it('cocina no cambia estados en modo directo', () => {
    expect(preparacion).toMatch(
      /IF v_directo THEN RETURN ven_obtener_pedido\(p_id\); END IF;/,
    );
  });

  it('el pedido informa el modo para que la UI ajuste los botones', () => {
    expect(obtenerPedido).toMatch(/'modo_entrega_directa',/);
    // Se devuelve como booleano, no como el 0/1 de la columna.
    expect(obtenerPedido).toMatch(/modo_entrega_directa[\s\S]*?\)\s*=\s*1/);
  });

  it('en modo directo aún se puede cancelar un plato comandado sin entregar', () => {
    expect(anularItem).toMatch(/v_directo/);
    expect(anularItem).toMatch(/NOT \(v_directo AND d\.estado_preparacion=4\)/);
  });

  it('el esquema consolidado incluye la columna en instalación nueva y en base existente', () => {
    const esquema = leer('esquema_completo_reejecutable.sql');
    // Instalación nueva: la columna viaja en el CREATE TABLE.
    expect(esquema).toMatch(
      /modo_entrega_directa\s+SMALLINT\s+NOT NULL DEFAULT 0/,
    );
    expect(esquema).toMatch(
      /CONSTRAINT ck_gen_empresa_modo_entrega CHECK \(modo_entrega_directa IN \(0, 1\)\)/,
    );
    // Base ya creada: CREATE TABLE IF NOT EXISTS no agrega columnas.
    expect(esquema).toMatch(
      /ALTER TABLE gen_empresa\s+ADD COLUMN IF NOT EXISTS modo_entrega_directa/,
    );
  });
});
