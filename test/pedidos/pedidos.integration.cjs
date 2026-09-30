// Pedidos e inventario se verifican juntos: producción, reservas, entregas y cancelaciones.
// Solo usa una base PostgreSQL local temporal; no lee .env.
require('../inventario/inventario.integration.cjs');
