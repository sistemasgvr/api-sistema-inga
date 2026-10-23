-- Recordatorios periódicos. El backend la llama cada hora; la clave única (que incluye
-- la fecha) hace que cada recordatorio se cree una sola vez al día, a cualquier hora.
DROP FUNCTION IF EXISTS public.not_generar_recordatorios();
CREATE OR REPLACE FUNCTION public.not_generar_recordatorios()
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE
  v_hoy DATE := (now() AT TIME ZONE 'America/Lima')::DATE;
  v_ref DATE; v_anio INTEGER; v_mes INTEGER; v_quincena INTEGER; v_fin DATE;
  v_cantidad INTEGER; v_nombres TEXT; v_creados INTEGER := 0; v_res JSON;
  v_meses TEXT[] := ARRAY['enero','febrero','marzo','abril','mayo','junio','julio',
                          'agosto','septiembre','octubre','noviembre','diciembre'];
  t RECORD;
BEGIN
  -- Planilla: la quincena que acaba de cerrar (1ra: hasta el 15; 2da: hasta fin de mes).
  IF v_hoy = (date_trunc('month', v_hoy) + INTERVAL '1 month - 1 day')::DATE THEN
    v_ref := v_hoy; v_quincena := 2;
  ELSIF EXTRACT(DAY FROM v_hoy) >= 15 THEN
    v_ref := v_hoy; v_quincena := 1;
  ELSE
    v_ref := (v_hoy - INTERVAL '1 month')::DATE; v_quincena := 2;
  END IF;
  v_anio := EXTRACT(YEAR FROM v_ref)::INTEGER;
  v_mes := EXTRACT(MONTH FROM v_ref)::INTEGER;
  v_fin := CASE WHEN v_quincena = 1 THEN make_date(v_anio, v_mes, 15)
                ELSE (make_date(v_anio, v_mes, 1) + INTERVAL '1 month - 1 day')::DATE END;

  SELECT count(*),
         string_agg(nombre, ', ' ORDER BY nombre) FILTER (WHERE rn <= 3)
  INTO v_cantidad, v_nombres
  FROM (
    SELECT TRIM(tr.nombres || ' ' || tr.apellidos) AS nombre,
           row_number() OVER (ORDER BY tr.nombres, tr.apellidos) AS rn
    FROM pla_trabajador tr
    WHERE tr.estado = 1
      AND (tr.fecha_creacion AT TIME ZONE 'America/Lima')::DATE <= v_fin
      AND NOT EXISTS (
        SELECT 1 FROM pla_pago p
        WHERE p.id_trabajador = tr.id AND p.estado = 1
          AND p.anio = v_anio AND p.mes = v_mes AND p.quincena = v_quincena
      )
  ) x;

  IF v_cantidad > 0 THEN
    v_res := not_crear(
      'planilla',
      'Pagos de planilla pendientes',
      v_cantidad || CASE WHEN v_cantidad = 1 THEN ' trabajador sin pago' ELSE ' trabajadores sin pago' END ||
        ' de la ' || CASE WHEN v_quincena = 1 THEN '1ra' ELSE '2da' END || ' quincena de ' ||
        v_meses[v_mes] || ' ' || v_anio || ': ' || v_nombres ||
        CASE WHEN v_cantidad > 3 THEN ' y ' || (v_cantidad - 3) || ' más.' ELSE '.' END,
      'warning',
      '/planilla?anio=' || v_anio || '&mes=' || v_mes || '&quincena=' || v_quincena,
      NULL, NULL,
      'pla-quincena:' || v_anio || '-' || v_mes || '-' || v_quincena || ':' || v_hoy,
      jsonb_build_object('anio', v_anio, 'mes', v_mes, 'quincena', v_quincena, 'pendientes', v_cantidad),
      FALSE
    );
    IF v_res->>'id' IS NOT NULL THEN v_creados := v_creados + 1; END IF;
  END IF;

  -- Caja: turnos que siguen abiertos desde un día anterior.
  FOR t IN
    SELECT tu.id, c.nombre AS caja, (tu.fecha_apertura AT TIME ZONE 'America/Lima')::DATE AS apertura
    FROM caj_turno tu
    JOIN caj_caja c ON c.id = tu.id_caja
    WHERE tu.estado = 1 AND tu.estado_turno = 1
      AND (tu.fecha_apertura AT TIME ZONE 'America/Lima')::DATE < v_hoy
  LOOP
    v_res := not_crear(
      'caja',
      'Caja abierta desde un día anterior',
      t.caja || ' sigue abierta desde el ' || to_char(t.apertura, 'DD/MM/YYYY') || '. Ciérrala para cuadrar el día.',
      'warning',
      '/caja/turnos?turno=' || t.id,
      t.id, NULL,
      'caj-turno-abierto:' || t.id || ':' || v_hoy,
      NULL,
      FALSE
    );
    IF v_res->>'id' IS NOT NULL THEN v_creados := v_creados + 1; END IF;
  END LOOP;

  RETURN json_build_object('creados', v_creados);
END; $$;
