# -*- coding: utf-8 -*-
"""
Genera esquema_completo_reejecutable.sql a partir de database.sql.

Lo escribi porque los dos archivos se me estaban desincronizando a mano: cada vez
que toco el esquema tengo que acordarme de tocar tambien el reejecutable, y eso
siempre termina mal. La transformacion es mecanica, asi que la automatizo.

Lo unico que hace: envolver cada "ALTER TABLE ... ADD CONSTRAINT ...;" suelta en
un bloque DO que ignora el error de constraint duplicada. Todo lo demas de
database.sql ya es idempotente por si solo.

Uso:  python utilidades/generar_reejecutable.py
"""
import io
import os
import re

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ORIGEN = os.path.join(BASE, 'database.sql')
DESTINO = os.path.join(BASE, 'esquema_completo_reejecutable.sql')

CABECERA = """-- =============================================================================
-- ESQUEMA COMPLETO - VERSION RE-EJECUTABLE
-- =============================================================================
--
-- GENERADO AUTOMATICAMENTE. No lo edites a mano: edita database.sql y vuelve a
-- correr  python utilidades/generar_reejecutable.py
--
-- Es database.sql con una sola diferencia: cada sentencia
-- ALTER TABLE ... ADD CONSTRAINT esta envuelta para que se salte si la
-- constraint ya existe. Eran las unicas que impedian volver a correr el
-- esquema sobre una base que ya tiene tablas creadas.
--
-- Todo lo demas ya era idempotente:
--   CREATE TABLE IF NOT EXISTS / CREATE INDEX IF NOT EXISTS
--   INSERT ... ON CONFLICT DO NOTHING|UPDATE
--   CREATE OR REPLACE VIEW|FUNCTION  (y DROP VIEW IF EXISTS donde cambian columnas)
--   los triggers ya hacen DROP TRIGGER IF EXISTS antes de crear
--
-- Se puede correr las veces que haga falta. Crea lo que falta y no toca lo
-- que ya esta. No borra ni modifica datos existentes.
-- =============================================================================
"""

PATRON = re.compile(r'^(ALTER TABLE .*ADD CONSTRAINT .*;)\s*$')


def main():
    with io.open(ORIGEN, encoding='utf-8') as fh:
        lineas = fh.read().split('\n')

    salida = [CABECERA]
    envueltas = 0
    for linea in lineas:
        m = PATRON.match(linea)
        if m:
            salida.append('DO $mig$ BEGIN')
            salida.append('    ' + m.group(1))
            salida.append('EXCEPTION WHEN duplicate_object THEN NULL;')
            salida.append('END $mig$;')
            envueltas += 1
        else:
            salida.append(linea)

    with io.open(DESTINO, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write('\n'.join(salida))

    print('OK: %d ALTER TABLE envueltos -> %s' % (envueltas, os.path.basename(DESTINO)))


if __name__ == '__main__':
    main()
