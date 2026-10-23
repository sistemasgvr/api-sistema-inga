// Rutas del front a las que lleva cada notificación. Deben existir en el App Router;
// los parámetros los lee la vista de destino para abrir el registro concreto.
export const RutasNotificacion = {
  pedido: (id: number) => `/ambientes/mesas?pedido=${id}`,
  venta: (id: number) => `/ventas?venta=${id}`,
  cocina: (idPedido: number) => `/productos/cocina?pedido=${idPedido}`,
  turno: (id: number) => `/caja/turnos?turno=${id}`,
  planilla: (anio: number, mes: number, quincena: number) =>
    `/planilla?anio=${anio}&mes=${mes}&quincena=${quincena}`,
  cuentaPorCobrar: (idPersona?: number | null) =>
    idPersona
      ? `/cuentas-por-cobrar/clientes/${idPersona}`
      : '/cuentas-por-cobrar',
  cuentaPorPagar: (idPersona?: number | null) =>
    idPersona
      ? `/cuentas-por-pagar?proveedor=${idPersona}`
      : '/cuentas-por-pagar',
  gastos: () => '/gastos',
  gastosDiarios: () => '/gastos/diarios',
};
