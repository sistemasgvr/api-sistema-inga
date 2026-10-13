-- Medio de pago y turno de caja en los abonos de CxC.
-- Re-ejecutable: no falla si las columnas o la FK ya existen.
--
-- Hasta ahora el abono del consorcio solo bajaba la deuda: el dinero que entraba
-- no aparecía en la caja y el cuadre del día salía con sobrante. Con el medio de
-- pago y el turno, caj_calcular_totales_turno lo suma (y el efectivo entra al
-- efectivo esperado del cajón). Después de esto hay que volver a cargar:
--   funciones/cuentas-por-cobrar/cxc_registrar_abono.sql
--   funciones/cuentas-por-cobrar/cxc_anular_movimiento.sql
--   funciones/cuentas-por-cobrar/cxc_obtener_movimiento.sql
--   funciones/cuentas-por-cobrar/cxc_obtener_estado_cuenta.sql
--   funciones/caja/turnos/caj_calcular_totales_turno.sql

ALTER TABLE cxc_movimiento ADD COLUMN IF NOT EXISTS id_turno BIGINT;
ALTER TABLE cxc_movimiento ADD COLUMN IF NOT EXISTS medio_pago SMALLINT;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_cxc_movimiento_turno') THEN
        ALTER TABLE cxc_movimiento
            ADD CONSTRAINT fk_cxc_movimiento_turno FOREIGN KEY (id_turno) REFERENCES caj_turno (id);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS ix_cxc_movimiento_turno ON cxc_movimiento (id_turno) WHERE id_turno IS NOT NULL;

COMMENT ON COLUMN cxc_movimiento.medio_pago IS
    'Solo en abonos. Catalogo MEDIO_PAGO: 1 efectivo, 2 yape, 3 tarjeta/transferencia. Solo el efectivo afecta el cajon.';
COMMENT ON COLUMN cxc_movimiento.id_turno IS
    'Turno de caja donde entro el abono. Obligatorio si medio_pago = 1 (efectivo), para que el cuadre del dia cierre.';
