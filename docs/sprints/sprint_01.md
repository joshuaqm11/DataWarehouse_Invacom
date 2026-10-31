# Sprint 1 · 17 – 23 de octubre 2026

**Scrum Master:** Joshua
**Objetivo del sprint:** entender la fuente, cerrar requisitos y modelo dimensional, y dejar el esquema del DW y la conexión Python funcionando en las 4 máquinas.

## Sprint Backlog

| Tarjeta | Responsable | Estado |
|---|---|---|
| Estructura del repo, README, .gitignore | Joshua | Hecho |
| Crear esquema DW_INVACOM en cada máquina (script 00) | Todos | Hecho |
| Inventario de la fuente (`01_inventario_fuente.sql`) | Fernanda | Hecho |
| Perfilado de calidad + `docs/calidad_datos.md` | Fernanda | Pasa al Sprint 2 |
| Requisitos: problema, objetivo general, objetivos específicos, preguntas de negocio | Fernanda + Fabio | Pasa al Sprint 2 |
| Entorno Python + `test_conexion.py` OK en su máquina | Todos | Hecho |
| Modelo dimensional (diagrama + granularidad) | Joshua + Joseph | Hecho |
| DDL de dimensiones y hechos (`sql/dw/`) | Joshua | Hecho |
| ETL completo con validación y reejecución sin duplicados (`etl/`) | Joshua | Hecho (adelantado del Sprint 2) |
| Database links staging ↔ producción | Fernanda | Hecho (adelantado) |
| Vistas para Excel e informes 1 a 4 | Fabio | Hecho (adelantado) |
| Informes 5 a 7 y Tablero | Joseph | Hecho (adelantado) |

## Daily (asíncrono)
Registrado en WhatsApp: qué hice · qué haré · bloqueos. Capturas en esta carpeta.

## Cierre del sprint (Sprint Review)
- **Completado:** DDL del DW, ETL completo con validación y reejecución sin duplicados, database links, vistas para Excel, 7 informes y Tablero.
- **Pendiente / bloqueado:** resultados de calidad, requisitos escritos, actas. Excel LTSC sin conector Oracle (Joseph): se usa la máquina de Joshua para actualizar el libro.
- **Bloqueos resueltos:** ORA-65096 al crear el usuario del DW (se cambió a la PDB); ORA-12899 en `DIM_TIEMPO.anio_mes` (se amplió la columna); falta de driver ODAC en Excel (se instaló Oracle Client for Microsoft Tools).
- **Decisiones tomadas:** constelación con 2 hechos (ventas por ítem, pagos por orden); cliente por `customer_unique_id`; ETL en Python (Pandas + SQLAlchemy); Excel conectado vía vistas.
