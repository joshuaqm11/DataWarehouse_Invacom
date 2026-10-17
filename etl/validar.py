"""VALIDACIÓN: compara la fuente con el DW para demostrar que la carga es correcta.

Se ejecuta al final de main.py y también de forma independiente:
    python etl/validar.py
"""
import sys

from sqlalchemy import text

from config import engine_dw, engine_fuente
from utils import log

TOLERANCIA = 0.01  # BRL

FUENTE = {
    "items": "SELECT COUNT(*) FROM STG_ORDER_ITEMS",
    "pagos": "SELECT COUNT(*) FROM STG_ORDER_PAYMENTS",
    "ordenes_con_items": "SELECT COUNT(DISTINCT order_id) FROM STG_ORDER_ITEMS",
    "clientes": "SELECT COUNT(DISTINCT customer_unique_id) FROM STG_CUSTOMERS",
    "productos": "SELECT COUNT(DISTINCT product_id) FROM STG_PRODUCTS",
    "vendedores": "SELECT COUNT(DISTINCT seller_id) FROM STG_SELLERS",
    "suma_precio": "SELECT ROUND(SUM(price), 2) FROM STG_ORDER_ITEMS",
    "suma_flete": "SELECT ROUND(SUM(freight_value), 2) FROM STG_ORDER_ITEMS",
    "suma_pagos": "SELECT ROUND(SUM(payment_value), 2) FROM STG_ORDER_PAYMENTS",
}

DW = {
    "items": "SELECT COUNT(*) FROM FACT_VENTAS",
    "pagos": "SELECT COUNT(*) FROM FACT_PAGOS",
    "ordenes_con_items": "SELECT COUNT(DISTINCT order_id) FROM FACT_VENTAS",
    "clientes": "SELECT COUNT(*) FROM DIM_CLIENTE WHERE sk_cliente > 0",
    "productos": "SELECT COUNT(*) FROM DIM_PRODUCTO WHERE sk_producto > 0",
    "vendedores": "SELECT COUNT(*) FROM DIM_VENDEDOR WHERE sk_vendedor > 0",
    "suma_precio": "SELECT ROUND(SUM(precio), 2) FROM FACT_VENTAS",
    "suma_flete": "SELECT ROUND(SUM(flete), 2) FROM FACT_VENTAS",
    "suma_pagos": "SELECT ROUND(SUM(monto_pago), 2) FROM FACT_PAGOS",
}

# Controles internos del DW: el resultado esperado es 0
CONTROLES_DW = {
    "Duplicados en FACT_VENTAS (order_id, order_item_id)":
        "SELECT COUNT(*) FROM (SELECT order_id, order_item_id FROM FACT_VENTAS "
        "GROUP BY order_id, order_item_id HAVING COUNT(*) > 1)",
    "Duplicados en FACT_PAGOS (order_id, payment_sequential)":
        "SELECT COUNT(*) FROM (SELECT order_id, payment_sequential FROM FACT_PAGOS "
        "GROUP BY order_id, payment_sequential HAVING COUNT(*) > 1)",
    "Ventas con producto Desconocido": "SELECT COUNT(*) FROM FACT_VENTAS WHERE sk_producto = -1",
    "Ventas con vendedor Desconocido": "SELECT COUNT(*) FROM FACT_VENTAS WHERE sk_vendedor = -1",
    "Ventas con cliente Desconocido": "SELECT COUNT(*) FROM FACT_VENTAS WHERE sk_cliente = -1",
    "Ventas sin fecha de compra": "SELECT COUNT(*) FROM FACT_VENTAS WHERE sk_fecha_compra = -1",
    "Pagos con cliente Desconocido": "SELECT COUNT(*) FROM FACT_PAGOS WHERE sk_cliente = -1",
    "Ventas con monto_total <> precio + flete":
        "SELECT COUNT(*) FROM FACT_VENTAS WHERE ABS(monto_total - (precio + flete)) > 0.01",
    "Entregadas a tiempo con atraso positivo":
        "SELECT COUNT(*) FROM FACT_VENTAS WHERE entregado_a_tiempo = 1 AND dias_atraso > 0",
}

NOMBRES = {
    "items": "Filas de ítems (ventas)", "pagos": "Filas de pagos",
    "ordenes_con_items": "Órdenes distintas con ítems", "clientes": "Clientes reales",
    "productos": "Productos", "vendedores": "Vendedores",
    "suma_precio": "Suma de precio (BRL)", "suma_flete": "Suma de flete (BRL)",
    "suma_pagos": "Suma de pagos (BRL)",
}


def _valores(engine, consultas: dict) -> dict:
    with engine.connect() as conn:
        return {k: conn.execute(text(sql)).scalar() for k, sql in consultas.items()}


def validar() -> bool:
    fuente = _valores(engine_fuente(), FUENTE)
    dw = _valores(engine_dw(), DW)
    controles = _valores(engine_dw(), CONTROLES_DW)

    ok_total = True
    log.info("  %-34s %16s %16s  %s", "Comparación fuente vs DW", "Fuente", "DW", "Resultado")
    for clave, nombre in NOMBRES.items():
        f, d = float(fuente[clave] or 0), float(dw[clave] or 0)
        ok = abs(f - d) <= TOLERANCIA
        ok_total &= ok
        log.info("  %-34s %16s %16s  %s", nombre, f"{f:,.2f}" if "suma" in clave else f"{f:,.0f}",
                 f"{d:,.2f}" if "suma" in clave else f"{d:,.0f}", "OK" if ok else "REVISAR")

    log.info("  %-58s %8s  %s", "Controles internos del DW (esperado 0)", "Valor", "Resultado")
    for nombre, valor in controles.items():
        ok = int(valor or 0) == 0
        ok_total &= ok
        log.info("  %-58s %8s  %s", nombre, f"{int(valor or 0):,}", "OK" if ok else "REVISAR")

    if ok_total:
        log.info("  VALIDACIÓN SUPERADA: el DW cuadra con la fuente.")
    else:
        log.warning("  Hay controles para REVISAR (ver rechazados en logs/ y reglas en docs/reglas_etl.md).")
    return ok_total


if __name__ == "__main__":
    from utils import configurar_log
    configurar_log()
    sys.exit(0 if validar() else 1)
