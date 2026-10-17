"""Punto de entrada del ETL Olist -> DW_INVACOM.

Ejecutar desde la raíz del repositorio (con el entorno virtual activo):
    python etl/main.py

Flujo:
    1. EXTRAER     tablas STG_* de la fuente                       (extract.py)
    2. TRANSFORMAR dimensiones                                      (transform.py)
    3. CARGAR      en UNA transacción: vaciar hechos, MERGE de
                   dimensiones, leer claves sustitutas, transformar
                   e insertar hechos -> COMMIT (o ROLLBACK si falla) (load.py)
    4. VALIDAR     fuente vs DW                                     (validar.py)
    5. BITÁCORA    resumen en consola, logs/ y tabla ETL_LOG_CARGA
"""
import sys
import time
import traceback

import extract
import load
import transform
from config import engine_dw, engine_fuente
from utils import ID_EJECUCION, RECHAZOS, configurar_log, fmt, log
from validar import validar


def _fase(titulo: str) -> float:
    log.info("=" * 70)
    log.info(titulo)
    return time.perf_counter()


def main() -> int:
    archivo_log = configurar_log()
    inicio_total = time.perf_counter()
    bitacora: list[dict] = []
    log.info("ETL Invacom · ejecución %s · bitácora: %s", ID_EJECUCION, archivo_log.name)
    eng_dw = engine_dw()

    try:
        # 1. EXTRACCIÓN ------------------------------------------------------
        t = _fase("1/4 EXTRACCIÓN desde el esquema fuente")
        src = extract.extraer_todo(engine_fuente())
        log.info("  Extracción completa en %.1f s", time.perf_counter() - t)

        # 2. TRANSFORMACIÓN DE DIMENSIONES ----------------------------------
        t = _fase("2/4 TRANSFORMACIÓN de dimensiones")
        geo = transform.transformar_geolocalizacion(src["geolocation"])
        dims = {
            "DIM_TIEMPO": transform.dim_tiempo(src["orders"]),
            "DIM_CLIENTE": transform.dim_cliente(src["customers"], src["orders"], geo),
            "DIM_VENDEDOR": transform.dim_vendedor(src["sellers"], geo),
            "DIM_PRODUCTO": transform.dim_producto(src["products"], src["category_translation"]),
            "DIM_ESTADO_ORDEN": transform.dim_estado_orden(src["orders"]),
            "DIM_TIPO_PAGO": transform.dim_tipo_pago(src["order_payments"]),
        }
        ordenes = transform.preparar_ordenes(src["orders"], src["customers"])
        reviews = transform.review_por_orden(src["order_reviews"])
        log.info("  Transformación de dimensiones en %.1f s", time.perf_counter() - t)

        # 3. CARGA (una sola transacción) -----------------------------------
        t = _fase("3/4 CARGA en DW_INVACOM (transacción única)")
        with eng_dw.begin() as conn:
            load.vaciar_hechos(conn)
            for tabla, df in dims.items():
                t0 = time.perf_counter()
                n = load.cargar_dimension(conn, tabla, df)
                bitacora.append({"tabla": tabla, "filas_leidas": len(df), "filas_cargadas": n,
                                 "filas_rechazadas": RECHAZOS.get(tabla.lower(), 0), "estado": "OK",
                                 "duracion_seg": round(time.perf_counter() - t0, 2)})

            claves = load.leer_claves(conn)
            fechas = load.fechas_validas(conn)

            log.info("  Transformando hechos con las claves sustitutas del DW...")
            hechos = {
                "FACT_VENTAS": (len(src["order_items"]),
                                transform.fact_ventas(src["order_items"], ordenes, reviews, claves, fechas)),
                "FACT_PAGOS": (len(src["order_payments"]),
                               transform.fact_pagos(src["order_payments"], ordenes, claves, fechas)),
            }
            for tabla, (leidas, df) in hechos.items():
                t0 = time.perf_counter()
                n = load.cargar_hecho(conn, tabla, df)
                bitacora.append({"tabla": tabla, "filas_leidas": leidas, "filas_cargadas": n,
                                 "filas_rechazadas": RECHAZOS.get(tabla.lower(), 0), "estado": "OK",
                                 "duracion_seg": round(time.perf_counter() - t0, 2)})
            log.info("  COMMIT · carga confirmada en %.1f s", time.perf_counter() - t)

    except Exception as e:
        log.error("ERROR: la carga se revirtió (ROLLBACK). El DW quedó como antes de esta ejecución.")
        log.error("%s: %s", type(e).__name__, e)
        log.debug(traceback.format_exc())
        load.registrar_bitacora(eng_dw, ID_EJECUCION, [{
            "tabla": "ETL", "estado": "ERROR",
            "duracion_seg": round(time.perf_counter() - inicio_total, 2),
            "mensaje": f"{type(e).__name__}: {e}"[:3900]}])
        return 1

    # 4. VALIDACIÓN -----------------------------------------------------------
    _fase("4/4 VALIDACIÓN fuente vs DW")
    valido = validar()

    # 5. RESUMEN --------------------------------------------------------------
    duracion = round(time.perf_counter() - inicio_total, 2)
    bitacora.append({"tabla": "ETL", "estado": "OK" if valido else "REVISAR", "duracion_seg": duracion,
                     "mensaje": "Validación superada" if valido else "Validación con observaciones"})
    load.registrar_bitacora(eng_dw, ID_EJECUCION, bitacora)

    log.info("=" * 70)
    log.info("RESUMEN  %-18s %10s %10s %10s", "Tabla", "Leídas", "Cargadas", "Rechazadas")
    for f in bitacora[:-1]:
        log.info("         %-18s %10s %10s %10s", f["tabla"], fmt(f["filas_leidas"]),
                 fmt(f["filas_cargadas"]), fmt(f["filas_rechazadas"]))
    log.info("Duración total: %.1f s · Estado: %s", duracion, "OK" if valido else "REVISAR")
    return 0 if valido else 2


if __name__ == "__main__":
    sys.exit(main())
