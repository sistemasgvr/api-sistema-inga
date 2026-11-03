
BEGIN;

UPDATE auth_permiso
SET estado = 0
WHERE codigo IN ('sucursales.crear', 'sucursales.editar', 'sucursales.eliminar', 'sucursales.activar')
  AND estado <> 0;

UPDATE auth_rol_permiso rp
SET estado = 0,
    fecha_modificacion = CURRENT_TIMESTAMP
FROM auth_permiso p
WHERE p.id = rp.id_permiso
  AND p.codigo IN ('sucursales.crear', 'sucursales.editar', 'sucursales.eliminar', 'sucursales.activar')
  AND rp.estado = 1;

COMMIT;
