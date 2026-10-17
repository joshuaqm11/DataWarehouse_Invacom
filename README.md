# Data Warehouse Invacom Inc. S.A. — Proyecto #1 Minería de Datos (3C 2026)

Universidad Técnica Nacional · ISW-911

Data Warehouse construido sobre la base **Olist E-commerce** (Brasil, 2016–2018) con un proceso ETL en **Python (Pandas + SQLAlchemy)** sobre **Oracle**, y visualización con tablas dinámicas de **Excel**.

## Equipo

| Integrante | Rol principal |
|---|---|
| Joshua | Scrum Master / coordinador · DDL del DW · orquestación (`main.py`) |
| Fernanda | Exploración y calidad de datos · requisitos · documento APA 7 |
| Joseph | Extracción · ETL de dimensiones |
| Fabio | ETL de hechos · validaciones · informes Excel |

Tablero Kanban: GitHub Projects → *Proyecto Data Warehouse + ETL - Invacom*.

## Arquitectura

```
Oracle (esquema fuente: STG_*)  ──extract──►  Pandas  ──transform──►  Pandas  ──load──►  Oracle (esquema DW_INVACOM)  ──►  Excel
```

- **Fuente:** 9 tablas `STG_*` (≈1.55 M filas, 1 M de ellas en `STG_GEOLOCATION`). No se modifican.
- **Destino:** esquema separado `DW_INVACOM` con dimensiones y hechos.

## Estructura del repositorio

```
docs/              documento APA, acuerdos, actas de sprint, evidencias
sql/exploracion/   consultas de inventario y perfilado de calidad (fuente)
sql/dw/            DDL del Data Warehouse (crear usuario, dimensiones, hechos)
sql/validacion/    consultas de control post-carga
etl/               código Python del ETL
informes/          archivo Excel y evidencias de conexión
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

## Ejecutar el ETL

Requisitos (una vez): `sql/dw/01_dimensiones.sql`, `02_hechos.sql` y `03_control_etl.sql` ejecutados con la conexión DW_INVACOM.

```bash
.venv\Scripts\activate
python etl/main.py          # extrae, transforma, carga y valida (≈ 2-5 min)
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
| 1 | 17 – 23 oct | Exploración, calidad, requisitos, modelo dimensional, DDL, conexión Python y Excel |
| 2 | 24 – 30 oct | ETL completo, validaciones, reejecución sin duplicados |
| 3 | 31 oct – 6 nov | Tablas dinámicas, documento APA 7, ensayo de la defensa |
