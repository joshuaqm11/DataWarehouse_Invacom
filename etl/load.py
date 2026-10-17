"""CARGA: escribe dimensiones y hechos en el esquema DW_INVACOM.

Estrategia (reejecutable sin duplicar):
  - Dimensiones: MERGE por clave natural (SCD tipo 1). Si la fila existe se
    actualiza; si no, se inserta. Las claves sustitutas no cambian entre cargas.
  - Hechos: carga completa controlada. Se borran y se vuelven a insertar dentro
    de la MISMA transacción; si algo falla, ROLLBACK y el DW queda como estaba.

SQLAlchemy gestiona la conexión y la transacción; para la inserción masiva se usa
el cursor del driver (executemany por lotes) con tipos declarados, que es mucho
más rápido que insertar fila por fila.
"""
import time

import numpy as np
import oracledb
import pandas as pd
from sqlalchemy import text
from sqlalchemy.engine import Connection

from utils import fmt, log

TAMANO_LOTE = 5_000

# tabla -> (claves naturales, columnas a actualizar, columna clave sustituta)
DIMENSIONES = {
    "DIM_TIEMPO": (["sk_tiempo"], ["fecha", "anio", "trimestre", "mes", "nombre_mes", "anio_mes",
                                   "dia", "dia_semana", "nombre_dia", "es_fin_semana"], "sk_tiempo"),
    "DIM_CLIENTE": (["customer_unique_id"], ["codigo_postal", "ciudad", "estado", "region",
                                             "latitud", "longitud"], "sk_cliente"),
    "DIM_VENDEDOR": (["seller_id"], ["codigo_postal", "ciudad", "estado", "region",
                                     "latitud", "longitud"], "sk_vendedor"),
    "DIM_PRODUCTO": (["product_id"], ["categoria_pt", "categoria_en", "peso_g", "largo_cm", "alto_cm",
                                      "ancho_cm", "volumen_cm3", "rango_peso", "cantidad_fotos"], "sk_producto"),
    "DIM_ESTADO_ORDEN": (["estado_orden"], ["estado_orden_es", "es_completada"], "sk_estado_orden"),
    "DIM_TIPO_PAGO": (["tipo_pago"], ["tipo_pago_es"], "sk_tipo_pago"),
}


# ---------------------------------------------------------------------------
# Conversión DataFrame -> parámetros del driver
# ---------------------------------------------------------------------------
def _a_registros(df: pd.DataFrame) -> list[dict]:
    """Convierte a tipos nativos de Python (int, float, str, datetime, None)."""
    registros = df.astype(object).where(pd.notna(df), None).to_dict("records")
    for r in registros:
        for k, v in r.items():
            if isinstance(v, np.generic):
                r[k] = v.item()
            elif isinstance(v, pd.Timestamp):
                r[k] = v.to_pydatetime()
    return registros


def _tipos_oracle(df: pd.DataFrame) -> dict:
    """Declara el tipo de cada parámetro para que los nulos no confundan al driver."""
    tipos = {}
    for c in df.columns:
        if pd.api.types.is_datetime64_any_dtype(df[c]):
            tipos[c] = oracledb.DB_TYPE_DATE
        elif pd.api.types.is_numeric_dtype(df[c]):
            tipos[c] = oracledb.DB_TYPE_NUMBER
        else:
            # ×4: margen para caracteres de varios bytes en UTF-8 (tildes)
            largo = df[c].astype("string").str.len().max()
            tipos[c] = min(int(largo) * 4, 4000) if pd.notna(largo) and largo > 0 else 1
    return tipos


def _ejecutar_lotes(conn: Connection, sql: str, df: pd.DataFrame) -> int:
    if df.empty:
        return 0
    registros = _a_registros(df)
    tipos = _tipos_oracle(df)
    cursor = conn.connection.cursor()
    try:
        for i in range(0, len(registros), TAMANO_LOTE):
            cursor.setinputsizes(**tipos)
            cursor.executemany(sql, registros[i:i + TAMANO_LOTE])
    finally:
        cursor.close()
    return len(registros)


# ---------------------------------------------------------------------------
# Dimensiones
# ---------------------------------------------------------------------------
def _sql_merge(tabla: str, claves: list[str], columnas: list[str]) -> str:
    todas = claves + columnas
    origen = ", ".join(f":{c} AS {c}" for c in todas)
    union = " AND ".join(f"t.{c} = s.{c}" for c in claves)
    actualizar = ", ".join(f"t.{c} = s.{c}" for c in columnas)
    return (f"MERGE INTO {tabla} t USING (SELECT {origen} FROM dual) s ON ({union}) "
            f"WHEN MATCHED THEN UPDATE SET {actualizar} "
            f"WHEN NOT MATCHED THEN INSERT ({', '.join(todas)}) VALUES ({', '.join('s.' + c for c in todas)})")


def cargar_dimension(conn: Connection, tabla: str, df: pd.DataFrame) -> int:
    claves, columnas, _ = DIMENSIONES[tabla]
    inicio = time.perf_counter()
    n = _ejecutar_lotes(conn, _sql_merge(tabla, claves, columnas), df[claves + columnas])
    log.info("  %-17s %8s filas (MERGE)  %.1f s", tabla, fmt(n), time.perf_counter() - inicio)
    return n


def leer_claves(conn: Connection) -> dict[str, pd.Series]:
    """Devuelve, por dimensión, una serie clave_natural -> clave_sustituta."""
    consultas = {
        "cliente": "SELECT customer_unique_id nk, sk_cliente sk FROM DIM_CLIENTE",
        "vendedor": "SELECT seller_id nk, sk_vendedor sk FROM DIM_VENDEDOR",
        "producto": "SELECT product_id nk, sk_producto sk FROM DIM_PRODUCTO",
        "estado_orden": "SELECT estado_orden nk, sk_estado_orden sk FROM DIM_ESTADO_ORDEN",
        "tipo_pago": "SELECT tipo_pago nk, sk_tipo_pago sk FROM DIM_TIPO_PAGO",
    }
    claves = {}
    for nombre, sql in consultas.items():
        df = pd.read_sql(text(sql), conn)
        df.columns = [c.lower() for c in df.columns]
        claves[nombre] = df.set_index("nk")["sk"]
    return claves


def fechas_validas(conn: Connection) -> set[int]:
    df = pd.read_sql(text("SELECT sk_tiempo FROM DIM_TIEMPO WHERE sk_tiempo > 0"), conn)
    return set(df.iloc[:, 0].astype("int64"))


# ---------------------------------------------------------------------------
# Hechos
# ---------------------------------------------------------------------------
def vaciar_hechos(conn: Connection) -> None:
    for tabla in ("FACT_VENTAS", "FACT_PAGOS"):
        n = conn.execute(text(f"DELETE FROM {tabla}")).rowcount
        log.info("  %s: %s filas anteriores eliminadas (recarga completa)", tabla, fmt(n))


def cargar_hecho(conn: Connection, tabla: str, df: pd.DataFrame) -> int:
    inicio = time.perf_counter()
    columnas = list(df.columns)
    sql = f"INSERT INTO {tabla} ({', '.join(columnas)}) VALUES ({', '.join(':' + c for c in columnas)})"
    n = _ejecutar_lotes(conn, sql, df)
    log.info("  %-17s %8s filas (INSERT) %.1f s", tabla, fmt(n), time.perf_counter() - inicio)
    return n


# ---------------------------------------------------------------------------
# Bitácora en el DW (tabla ETL_LOG_CARGA)
# ---------------------------------------------------------------------------
def registrar_bitacora(engine, id_ejecucion: str, filas: list[dict]) -> None:
    """Se escribe en una transacción aparte para que quede aunque la carga falle."""
    sql = text("""INSERT INTO ETL_LOG_CARGA
                  (id_ejecucion, tabla, filas_leidas, filas_cargadas, filas_rechazadas,
                   estado, duracion_seg, mensaje)
                  VALUES (:id_ejecucion, :tabla, :filas_leidas, :filas_cargadas,
                          :filas_rechazadas, :estado, :duracion_seg, :mensaje)""")
    try:
        with engine.begin() as conn:
            for f in filas:
                conn.execute(sql, {"id_ejecucion": id_ejecucion, "filas_leidas": None,
                                   "filas_cargadas": None, "filas_rechazadas": None,
                                   "duracion_seg": None, "mensaje": None, **f})
    except Exception as e:  # la bitácora nunca debe tumbar el ETL
        log.warning("No se pudo escribir ETL_LOG_CARGA (¿ejecutaron sql/dw/03_control_etl.sql?): %s", e)
