# Guía de la demo en vivo · Defensa DW Invacom

Responsable: Joshua · Máquina de demo: la de Joshua · Duración de la demo: unos 8 minutos

Esta guía dice qué preparar antes de la defensa y qué mostrar, en orden, frente al jurado. Cada paso indica el resultado esperado. Si algo no sale igual, se pasa al **Plan B** (al final).

---

## 1. Preparación (un día antes)

| # | Qué hacer | Resultado esperado |
|---|---|---|
| 1.1 | `git pull` en la carpeta del repo | Repo al día, sin cambios locales pendientes (`git status` limpio) |
| 1.2 | Verificar que Oracle esté arriba: en *Servicios* de Windows, `OracleServiceXE` y el servicio que termina en `TNSListener` | Ambos en *En ejecución* |
| 1.3 | `etl/.env` existe y tiene las credenciales locales | Archivo presente (nunca se sube a Git) |
| 1.4 | Ensayo completo de la sección 3, de principio a fin, cronometrado | Todo en verde, menos de 10 minutos |
| 1.5 | Cargar la laptop y empacar el cargador | — |

Comandos (PowerShell o terminal de VS Code, desde la raíz del repo):

```bash
git pull
git status
.venv\Scripts\activate
python etl/test_conexion.py
```

Esperado: `test_conexion.py` responde OK para la fuente y para `DW_INVACOM`.

---

## 2. Antes de entrar a presentar (30 minutos antes)

1. Encender la laptop, conectar el cargador y desactivar notificaciones (Windows: *Asistente de concentración*).
2. Correr el ETL una vez para que el DW y el Excel queden frescos:
   ```bash
   .venv\Scripts\activate
   python etl/main.py
   ```
3. Dejar abiertas, en este orden:

| Pestaña / ventana | Para qué |
|---|---|
| VS Code con la terminal en la raíz del repo y el `.venv` activo | Correr el ETL en vivo |
| SQL Developer con 2 conexiones: **ConexionProyecto** (fuente/staging) y **DW_INVACOM** | Bitácora y dblinks |
| `sql/validacion/02_cuadre_staging_produccion.sql` abierto en SQL Developer | Cuadre staging vs producción |
| `informes/Informes_DW_Invacom.xlsx` abierto en la hoja **Tablero** | Informes |
| Navegador: repositorio en GitHub y el tablero Kanban | Git y Scrum |
| Explorador de archivos en `docs/evidencias/` | Plan B |

4. Subir el tamaño de letra de la terminal y de SQL Developer (Ctrl + rueda del mouse) para que se lea en el proyector.

---

## 3. Guion de la demo (frente al jurado)

### Paso 1 · Ejecutar el ETL (≈ 1 min)

```bash
python etl/main.py
```

**Qué se ve:** las 4 fases (extracción, transformación, carga en una sola transacción, validación) y el resumen final.

**Esperado:**
- `FACT_VENTAS` 112,650 cargadas · `FACT_PAGOS` 103,886 cargadas · 0 rechazadas
- Validación fuente vs DW en **OK** (conteos y sumas al centavo)
- `Duración total: ≈ 25 s · Estado: OK`

**Qué decir:** "El ETL extrae las 9 tablas STG con SQLAlchemy, aplica 18 reglas de limpieza en Pandas y carga todo en una sola transacción: si algo falla, hace ROLLBACK y el DW queda como estaba. Al final se valida solo contra la fuente."

### Paso 2 · Reejecutar sin duplicar (≈ 30 s)

```bash
python etl/main.py
```

**Esperado:** los mismos 112,650 y 103,886 (no 225,300).

**Qué decir:** "Las dimensiones usan MERGE y los hechos se recargan dentro de la transacción, así que se puede correr las veces que se quiera sin duplicar."

### Paso 3 · Bitácora de cargas (≈ 30 s)

En SQL Developer, conexión **DW_INVACOM**:

```sql
SELECT id_ejecucion, tabla, filas_leidas, filas_cargadas, filas_rechazadas, estado, duracion_seg
FROM   ETL_LOG_CARGA
WHERE  id_ejecucion = (SELECT MAX(id_ejecucion) FROM ETL_LOG_CARGA)
ORDER  BY id_log;
```

**Esperado:** una fila por tabla con estado OK y la fila `ETL` con "Validación superada".

**Qué decir:** "Cada ejecución queda registrada: cuánto se leyó, cargó y rechazó. Las filas rechazadas, si las hubiera, quedan en `logs/rechazados_*.csv` con el motivo."

### Paso 4 · Cuadre staging vs producción con dblinks (≈ 2 min)

Archivo `sql/validacion/02_cuadre_staging_produccion.sql`, conexión **ConexionProyecto**. Ejecutar por bloque con **Ctrl+Enter**:

| Bloque | Esperado |
|---|---|
| 1. Cuadre general | Todos los controles en OK, diferencia 0 |
| 2. Ítems de staging que no llegaron a producción | 0 filas |
| 6.1 Simular cambio (+100 al precio de un ítem, sin confirmar) | 1 fila actualizada |
| 6.2 El cuadre expone la diferencia | 2 filas: STAGING con 100 más que PRODUCCION |
| 6.3 `ROLLBACK` | Cambio deshecho |
| 6.4 Verificar | `diferencias = 0` |

**Qué decir:** "Con database links comparamos fila por fila staging contra producción usando MINUS. Si alguien cambia un dato en la fuente, el cuadre lo detecta; aquí lo simulamos y lo deshicimos con ROLLBACK."

> **Obligatorio:** no saltarse el bloque 6.3 (`ROLLBACK`). Si se cierra SQL Developer con el cambio pendiente, elegir **Rollback** cuando lo pregunte.

### Paso 5 · Excel conectado al DW (≈ 3 min)

1. En el Excel: **Datos → Actualizar todo** (dos veces). Esperado: sin errores y los totales se mantienen.
2. Hoja **Tablero**: mostrar los KPI y usar una segmentación (por ejemplo, año 2018), luego quitar el filtro.
3. Recorrer los informes clave con su conclusión de una línea (detalle en `docs/conclusiones_informes.md`):
   - **1 Ventas por mes:** pico en noviembre de 2017 (Black Friday).
   - **3 Regiones:** el Sudeste concentra casi 2/3 de las ventas.
   - **5 Entregas:** Norte y Nordeste tardan casi el doble.
   - **6 Atraso y reseñas:** con 4 o más días de atraso, la nota cae a 2 o menos.
   - **7 Pagos:** la tarjeta de crédito concentra casi 4 de cada 5 reales.

**Qué decir:** "Excel se conecta directo a Oracle con Power Query sobre 3 vistas, una por granularidad, para que nada se sume dos veces. Si el ETL carga datos nuevos, basta con *Actualizar todo*."

### Paso 6 · Git y Kanban (≈ 1 min)

- GitHub → **Insights → Contributors** o la lista de commits: commits de los 4 integrantes.
- Tablero Kanban → **Slice by: Sprint**: la división de los 3 sprints.
- `docs/sprints/`: actas de cada sprint.

---

## 4. Plan B (si algo falla en vivo)

| Si falla… | Hacer |
|---|---|
| Oracle no arranca o no conecta | Mostrar `docs/evidencias/Ejecucion 1 de ETL.jpeg` y `Ejecucion 2 de ETL.jpeg` |
| El ETL da error | Leer el mensaje: el ETL hace ROLLBACK y el DW queda intacto (eso también es una demostración). Mostrar las evidencias de ejecución |
| Los dblinks no responden | Mostrar `cuadre_3_1.png`, `cuadre_5_*.png`, `diferencia_detectada .png` y `cuadre_restaurado .png` |
| Excel no actualiza (error de ODAC/Oracle) | No actualizar: el archivo ya tiene los datos de la última carga. Mostrar `Evidencia Conexion *.jpeg` |
| No hay proyector o internet | El ETL, Oracle y Excel funcionan sin internet; solo GitHub lo necesita (mostrar capturas del repo) |

---

## 5. Después de la demo

- [ ] Confirmar que no quedó ningún cambio pendiente en staging (`ROLLBACK` en la conexión ConexionProyecto).
- [ ] No guardar cambios en el `.xlsx` si solo se actualizó para la demo (evita conflictos en Git).
- [ ] Cerrar SQL Developer eligiendo **Rollback** si pregunta.
