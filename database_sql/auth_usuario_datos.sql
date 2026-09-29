CREATE OR REPLACE VIEW auth_usuario_datos AS
SELECT u.id, u.username, u.password_hash, u.pin_hash, u.es_super_admin,
       u.estado, u.fecha_creacion, u.fecha_modificacion, u.id_trabajador,
       t.nombres, t.apellidos, t.email, t.telefono,
       t.id_sucursal AS id_sucursal_default, t.estado AS estado_trabajador
FROM auth_usuario u
JOIN pla_trabajador t ON t.id = u.id_trabajador;
