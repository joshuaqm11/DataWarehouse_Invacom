# Sprint 3 · 31 de octubre – 6 de noviembre 2026

**Scrum Master:** Joshua
**Objetivo:** entregar el documento APA 7, preparar la presentación y ensayar la defensa con la demo en vivo.

## Sprint Backlog

| Tarjeta | Responsable | Estado |
|---|---|---|
| Resultados de calidad (pendiente del Sprint 2) | Fernanda | Hecho (31 oct, cierra #6) |
| Inventario de la fuente y requisitos, objetivos y preguntas de negocio | Fernanda | Hecho (31 oct, cierra #5 y #7) |
| Documento APA 7 (requisitos, necesidades, objetivos, solución, conclusión, bibliografía) | Fernanda | |
| Prueba de recuperación ante fallo (pendiente del Sprint 2) | Fabio | |
| Guía de Excel en `docs/` (pendiente del Sprint 2) | Fabio | |
| Evidencias de los informes 5 a 7 y del Tablero | Joseph | Hecho (1 nov) |
| Hoja de KPIs con línea base, meta y semáforo | Joseph | Hecho (3 nov) |
| Presentación de la defensa | Equipo (Joseph, Fernanda, Fabio) | |
| Máquina de demo lista: ETL, reejecución, bitácora, dblinks y Excel actualizando sin errores | Joshua | Hecho (4 nov) |
| Guía de la demo en vivo (`docs/guia_demo.md`) | Joshua | Hecho (4 nov) |
| Kanban con división por sprint y responsables según Git | Joshua | Hecho (4 nov) |
| Tabla de % de participación (`docs/participacion.md`) | Joshua (coordinador) | Hecho (4 nov) |
| Ensayo general de la defensa | Todos | |

## Daily (asíncrono)
Registrado en WhatsApp. Capturas en esta carpeta.

## Cierre del sprint (Sprint Review)
- **Completado:** calidad, inventario y requisitos (Fernanda); evidencias de los informes 5 a 7 y hoja de KPIs (Joseph); máquina de demo verificada el 4 nov (ETL 112,650 ítems y 103,886 pagos, 0 rechazados, validación OK, reejecución sin duplicados, bitácora, cuadre con dblinks en 0 y detección de cambios con ROLLBACK), guía de la demo, Kanban y tabla de participación (Joshua).
- **Pendiente / bloqueado:** 
- **Decisiones tomadas:** la demo se hace en la máquina de Joshua siguiendo `docs/guia_demo.md`; la presentación y el documento APA 7 quedan a cargo de Joseph, Fernanda y Fabio; el modelo se presenta como esquema estrella con dos tablas de hechos (ventas y pagos) que comparten dimensiones.
- **Bloqueo resuelto (4 nov):** en la máquina de demo faltaban la vista `V_CUADRE_STAGING_PRODUCCION` y el dblink `LNK_PRODUCCION` (ORA-00942, ORA-02019). Se crearon; el permiso se dio desde SYSTEM con `ALTER SESSION SET CONTAINER = XEPDB1` (ORA-01917 en el contenedor raíz).

## Retrospectiva del proyecto
- **Qué salió bien:** el DW quedó funcional y validado desde el Sprint 1, lo que dejó tiempo para documentar, analizar y probar; el ETL es reejecutable y cuadra al centavo con la fuente.
- **Qué mejorar:** repartir los commits de forma pareja cada semana (la semana del 24 al 30 de octubre tuvo poca actividad en el repositorio) y trabajar con ramas y Pull Requests.
- **Qué aprendimos:** modelado dimensional, ETL transaccional con Python (Pandas + SQLAlchemy), database links en Oracle y conexión de Excel a Oracle con Power Query.
