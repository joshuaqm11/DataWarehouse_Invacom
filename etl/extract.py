"""EXTRACCIÓN: lee de Oracle (esquema fuente) solo las columnas que usa el DW.

Cada consulta es explícita (sin SELECT *). El resultado es un diccionario
{nombre: DataFrame} con nombres de columna en minúscula.
"""
import time

import oracledb
import pandas as pd
from sqlalchemy import text
from sqlalchemy.engine import Engine

from utils import fmt, log

# Filas que el driver trae por viaje a la base: acelera la lectura de 1 M de filas
oracledb.defaults.arraysize = 10_000
oracledb.defaults.prefetchrows = 10_000

CONSULTAS = {
    "orders": """
        SELECT order_id, customer_id, order_status, order_purchase_timestamp,
               order_approved_at, order_delivered_carrier_date,
               order_delivered_customer_date, order_estimated_delivery_date
        FROM STG_ORDERS""",
    "order_items": """
        SELECT order_id, order_item_id, product_id, seller_id, price, freight_value
        FROM STG_ORDER_ITEMS""",
    "order_payments": """
        SELECT order_id, payment_sequential, payment_type,
               payment_installments, payment_value
        FROM STG_ORDER_PAYMENTS""",
    "order_reviews": """
        SELECT review_id, order_id, review_score,
               review_creation_date, review_answer_timestamp
        FROM STG_ORDER_REVIEWS""",
    "customers": """
        SELECT customer_id, customer_unique_id, customer_zip_code_prefix,
               customer_city, customer_state
        FROM STG_CUSTOMERS""",
    "sellers": """
        SELECT seller_id, seller_zip_code_prefix, seller_city, seller_state
        FROM STG_SELLERS""",
    "products": """
        SELECT product_id, product_category_name, product_photos_qty,
               product_weight_g, product_length_cm, product_height_cm, product_width_cm
        FROM STG_PRODUCTS""",
    "category_translation": """
        SELECT product_category_name, product_category_name_english
        FROM STG_PRODUCT_CATEGORY_TRANSLATION""",
    "geolocation": """
        SELECT geolocation_zip_code_prefix, geolocation_lat, geolocation_lng
        FROM STG_GEOLOCATION""",
}

COLUMNAS_FECHA = {
    "orders": ["order_purchase_timestamp", "order_approved_at", "order_delivered_carrier_date",
               "order_delivered_customer_date", "order_estimated_delivery_date"],
    "order_reviews": ["review_creation_date", "review_answer_timestamp"],
}


def extraer_todo(engine: Engine) -> dict[str, pd.DataFrame]:
    datos: dict[str, pd.DataFrame] = {}
    with engine.connect() as conn:
        for nombre, sql in CONSULTAS.items():
            inicio = time.perf_counter()
            df = pd.read_sql(text(sql), conn)
            df.columns = [c.lower() for c in df.columns]
            for col in COLUMNAS_FECHA.get(nombre, []):
                df[col] = pd.to_datetime(df[col], errors="coerce")
            datos[nombre] = df
            log.info("  %-22s %10s filas  (%.1f s)", nombre, fmt(len(df)), time.perf_counter() - inicio)
    return datos
