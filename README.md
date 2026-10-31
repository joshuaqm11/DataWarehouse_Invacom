# Data Warehouse Invacom Inc. S.A. — Proyecto #1 Minería de Datos (3C 2026)

Universidad Técnica Nacional · ISW-911

Data Warehouse construido sobre la base **Olist E-commerce** (Brasil, 2016–2018) con un proceso ETL en **Python (Pandas + SQLAlchemy)** sobre **Oracle**, y visualización con tablas dinámicas de **Excel**.

## Equipo

| Integrante | Rol principal |
|---|---|
| Joshua | Scrum Master / coordinador · DDL del DW · ETL (extracción, transformación, carga y validación) · actas |
| Fernanda | Inventario y calidad de datos · database links staging ↔ producción · documento APA 7 |
| Fabio | Vistas para Excel · conexión Excel–Oracle · informes 1 a 4 · prueba de recuperación |
| Joseph | Informes 5 a 7 · Tablero · diagrama del modelo y de la fuente · conclusiones |

Tablero Kanban: GitHub Projects → *Proyecto Data Warehouse + ETL - Invacom*.

## Arquitectura

```
Oracle (esquema fuente: STG_*)  ──extract──►  Pandas  ──transform──►  Pandas  ──load──►  Oracle (esquema DW_INVACOM)  ──►  Excel
```

- **Fuente:** 9 tablas `STG_*` (≈1.55 M filas, 1 M de ellas en `STG_GEOLOCATION`). No se modifican.
- **Destino:** esquema separado `DW_INVACOM` con dimensiones y hechos.

## Estructura del repositorio

```
docs/              modelo dimensional, relaciones de la fuente, calidad, reglas del ETL,
                   conclusiones, actas de sprint (docs/sprints/) y evidencias (docs/evidencias/)
sql/exploracion/   consultas de inventario y perfilado de calidad (fuente)
sql/dw/            00 usuario · 01 dimensiones · 02 hechos · 03 bitácora · 04 database links
                   · 05 vistas para Excel · 99 eliminar todo
sql/validacion/    consultas de control post-carga y cuadre staging vs producción
etl/               código Python del ETL
informes/          libro Excel con 7 informes y Tablero (Informes_DW_Invacom.xlsx)
```

## Puesta en marcha (cada integrante, en su base local)

Todos trabajamos contra **nuestra propia base Oracle local**, por eso todo lo necesario para reconstruir el DW está en este repo.

1. **Clonar / actualizar**
   ```bash
   git clone https://github.com/joshuaqm11/DataWarehouse_Invacom.git
   git pull          # siempre antes de empezar a trabajar
   ```
2. **Crear el esquema del DW** (una sola vez): abrir `sql/dw/00_crear_usuario_dw.sql` en SQL Developer conectado como **administrador** (SYSTEM) y ejecutarlo como script (F5).
3. **Entorno Python**
   ```bash
   python -m venv .venv
   .venv\Scripts\activate          # Windows
   pip install -r requirements.txt
   ```
4. **Configuración local:** copiar `etl/.env.example` a `etl/.env` y poner **sus** datos (usuario, contraseña, servicio). `etl/.env` **nunca** se sube a Git.
5. **Probar conexión**
   ```bash
   python etl/test_conexion.py
   ```
6. **Database links** (opcional): `sql/dw/04_dblinks.sql` (editar solo la sección `DEFINE` y ejecutar con F5).
7. **Vistas para Excel:** `sql/dw/05_vistas_excel.sql` con la conexión DW_INVACOM (F5), después de cargar el DW con el ETL.

## Excel

Requisito: Oracle Client for Microsoft Tools (OCMT) instalado, de la misma arquitectura que Office.

1. Abrir `informes/Informes_DW_Invacom.xlsx`.
2. **Datos → Actualizar todo** (dos veces: la primera recarga las hojas de datos, la segunda las tablas dinámicas).
3. Credenciales: **Base de datos**, usuario `DW_INVACOM`. Servidor: `localhost:1521/XEPDB1` (si su servicio es otro: Datos → Obtener datos → Configuración de origen de datos → Cambiar origen).

El libro lee las vistas `V_EXCEL_VENTAS`, `V_EXCEL_ORDENES` y `V_EXCEL_PAGOS`; no se pegan datos a mano.

## Ejecutar el ETL

Requisitos (una vez): `sql/dw/01_dimensiones.sql`, `02_hechos.sql` y `03_control_etl.sql` ejecutados con la conexión DW_INVACOM.

```bash
.venv\Scripts\activate
python etl/main.py          # extrae, transforma, carga y valida (≈ 25 s)
python etl/validar.py       # solo validación fuente vs DW
```

- Se puede ejecutar las veces que se quiera: **no duplica datos** (MERGE en dimensiones, recarga de hechos en una transacción).
- Bitácora: consola, `logs/etl_<fecha>.log` y tabla `ETL_LOG_CARGA` del DW.
- Filas rechazadas: `logs/rechazados_*.csv` con el motivo.
- Reglas de limpieza: `docs/reglas_etl.md`. Consultas de control: `sql/validacion/01_validaciones_dw.sql`.

| Módulo | Responsabilidad |
|---|---|
| `etl/extract.py` | Consultas explícitas a las tablas STG_* |
| `etl/transform.py` | Limpieza, enriquecimiento, dimensiones y hechos |
| `etl/load.py` | MERGE de dimensiones, carga de hechos, transacción, bitácora |
| `etl/validar.py` | Cuadre fuente vs DW y controles de integridad |
| `etl/main.py` | Orquestación y resumen |

## Convenciones de trabajo en Git

- Una rama por tarea: `feature/<tarjeta>-<nombre>` (ej. `feature/5-dim-producto`), luego Pull Request a `main` y revisión de otro integrante (columna *In Review* del tablero).
- Mensajes de commit en español, en presente: `Agrega perfilado de nulos en STG_ORDERS`.
- Referenciar la tarjeta: `... (#5)`.
- **Prohibido** subir contraseñas, `.env`, exportaciones de datos o archivos `.csv` de la base.

## Estado por sprint

| Sprint | Fechas | Objetivo |
|---|---|---|
| 1 | 17 – 23 oct | Modelo, DDL, ETL completo, validaciones, database links, vistas, 7 informes y Tablero |
| 2 | 24 – 30 oct | Diagramas, conclusiones, actas, README y Kanban; evidencia y documentación |
| 3 | 31 oct – 6 nov | Calidad, recuperación, documento APA 7, presentación y ensayo de la defensa |

Actas en `docs/sprints/`.
