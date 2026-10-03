# Arquitectura modular

Mantener el patrón de los módulos existentes en todos los cambios:

- Dejar el archivo `<nombre>.module.ts` en la raíz de cada módulo.
- Separar endpoints en `controllers/`, validaciones de entrada en `dto/`, reglas y orquestación en `logic/`, y acceso a base de datos en `models/`.
- Ubicar los gateways WebSocket en `gateways/`; delegar sus operaciones de negocio a la capa `logic/`.
- Los controladores no contienen DTO ni consultas SQL. La lógica usa modelos para consultar o modificar datos.
- Al mover archivos, corregir imports, providers, exports y referencias de pruebas, incluidos los scripts que importan archivos compilados de `dist/`.
- Verificar compilación y pruebas correspondientes después de reorganizar un módulo.
