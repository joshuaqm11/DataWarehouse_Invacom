"""TRANSFORMACIÓN: limpia la fuente y construye dimensiones y hechos.

Cada regla está documentada en docs/reglas_etl.md con el mismo código (R01, R02...).
Las funciones no tocan la base de datos: reciben y devuelven DataFrames.
"""
import numpy as np
import pandas as pd

from utils import fmt, guardar_rechazados, log, normalizar_texto

# ---------------------------------------------------------------------------
# Catálogos de enriquecimiento
# ---------------------------------------------------------------------------
REGIONES = {  # R05: estado (UF) -> región oficial de Brasil (IBGE)
    **dict.fromkeys(["AC", "AP", "AM", "PA", "RO", "RR", "TO"], "Norte"),
    **dict.fromkeys(["AL", "BA", "CE", "MA", "PB", "PE", "PI", "RN", "SE"], "Nordeste"),
    **dict.fromkeys(["DF", "GO", "MT", "MS"], "Centro-Oeste"),
    **dict.fromkeys(["ES", "MG", "RJ", "SP"], "Sudeste"),
    **dict.fromkeys(["PR", "RS", "SC"], "Sur"),
}

TRADUCCION_CATEGORIAS_FALTANTES = {  # R08: categorías que no vienen en la tabla de traducción
    "pc_gamer": "pc_gamer",
    "portateis_cozinha_e_preparadores_de_alimentos": "portable_kitchen_food_processors",
    "sin_categoria": "no_category",
}

ESTADOS_ORDEN = {  # R11
    "delivered": "Entregada", "shipped": "Enviada", "canceled": "Cancelada",
    "unavailable": "No disponible", "invoiced": "Facturada", "processing": "En proceso",
    "created": "Creada", "approved": "Aprobada",
}

TIPOS_PAGO = {  # R11
    "credit_card": "Tarjeta de crédito", "boleto": "Boleto bancario", "voucher": "Vale / cupón",
    "debit_card": "Tarjeta de débito", "not_defined": "No definido",
}

MESES = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio",
         "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
DIAS = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]

# Límites geográficos de Brasil (R04: coordenadas fuera se descartan)
LAT_MIN, LAT_MAX, LNG_MIN, LNG_MAX = -34.0, 5.5, -74.0, -34.0


# ---------------------------------------------------------------------------
# Auxiliares
# ---------------------------------------------------------------------------
def _limpiar_ids(df: pd.DataFrame, columnas: list[str]) -> pd.DataFrame:
    """R01: quita espacios en claves de texto y convierte '' en nulo."""
    for c in columnas:
        df[c] = df[c].astype("string").str.strip().replace("", pd.NA)
    return df


def _sk_fecha(serie: pd.Series, validas: set[int]) -> pd.Series:
    """Fecha -> clave AAAAMMDD de DIM_TIEMPO; nula o fuera del calendario -> -1."""
    sk = (serie.dt.year * 10000 + serie.dt.month * 100 + serie.dt.day).astype("Int64")
    return sk.where(sk.isin(validas), -1).fillna(-1).astype("int64")


def _mapear(serie: pd.Series, mapa: pd.Series) -> pd.Series:
    """Clave natural -> clave sustituta; sin coincidencia -> -1 (miembro Desconocido)."""
    return serie.map(mapa).fillna(-1).astype("int64")


def _avisar_desconocidos(df: pd.DataFrame, tabla: str, columnas: list[str]) -> None:
    for c in columnas:
        n = int((df[c] == -1).sum())
        if n:
            log.warning("  %s: %s filas con %s = -1 (Desconocido)", tabla, fmt(n), c)


# ---------------------------------------------------------------------------
# Geolocalización y ubicación
# ---------------------------------------------------------------------------
def transformar_geolocalizacion(geo: pd.DataFrame) -> pd.DataFrame:
    """R04: 1 M de filas -> 1 fila por código postal con coordenadas promedio."""
    g = geo.copy()
    g["geolocation_zip_code_prefix"] = g["geolocation_zip_code_prefix"].astype("string").str.strip().str.zfill(5)
    dentro = (g["geolocation_lat"].between(LAT_MIN, LAT_MAX)
              & g["geolocation_lng"].between(LNG_MIN, LNG_MAX)
              & g["geolocation_zip_code_prefix"].notna())
    fuera = int((~dentro).sum())
    if fuera:
        log.warning("  geolocalización: %s filas con coordenadas fuera de Brasil o sin código (descartadas)", fmt(fuera))
    res = (g[dentro]
           .groupby("geolocation_zip_code_prefix", as_index=False)
           .agg(latitud=("geolocation_lat", "mean"), longitud=("geolocation_lng", "mean"))
           .rename(columns={"geolocation_zip_code_prefix": "codigo_postal"}))
    res[["latitud", "longitud"]] = res[["latitud", "longitud"]].round(6)
    log.info("  geolocalización: %s filas -> %s códigos postales únicos", fmt(len(geo)), fmt(len(res)))
    return res


def _ubicacion(df: pd.DataFrame, zip_col: str, ciudad_col: str, estado_col: str,
               geo: pd.DataFrame) -> pd.DataFrame:
    """R02, R03, R05: código postal de 5 dígitos, ciudad normalizada, estado, región y coordenadas."""
    out = pd.DataFrame(index=df.index)
    out["codigo_postal"] = df[zip_col].astype("string").str.strip().str.zfill(5)
    out["ciudad"] = normalizar_texto(df[ciudad_col]).str.slice(0, 100).fillna("desconocida")
    out["estado"] = df[estado_col].astype("string").str.strip().str.upper()
    out["region"] = out["estado"].map(REGIONES).fillna("Desconocida")
    out["estado"] = out["estado"].fillna("NA")
    out = out.merge(geo, on="codigo_postal", how="left")
    out.index = df.index
    return out


# ---------------------------------------------------------------------------
# Dimensiones
# ---------------------------------------------------------------------------
def dim_cliente(customers: pd.DataFrame, orders: pd.DataFrame, geo: pd.DataFrame) -> pd.DataFrame:
    """R06: una fila por customer_unique_id con la dirección de su orden más reciente."""
    c = _limpiar_ids(customers.copy(), ["customer_id", "customer_unique_id"])
    sin_id = c["customer_unique_id"].isna()
    guardar_rechazados(c[sin_id], "dim_cliente", "customer_unique_id nulo")
    c = c[~sin_id]

    ultima = orders[["customer_id", "order_purchase_timestamp"]]
    c = c.merge(ultima, on="customer_id", how="left")
    c = (c.sort_values("order_purchase_timestamp", ascending=False, na_position="last")
          .drop_duplicates("customer_unique_id", keep="first"))

    dim = pd.concat([c[["customer_unique_id"]],
                     _ubicacion(c, "customer_zip_code_prefix", "customer_city", "customer_state", geo)], axis=1)
    log.info("  DIM_CLIENTE: %s customer_id -> %s clientes reales", fmt(len(customers)), fmt(len(dim)))
    return dim.reset_index(drop=True)


def dim_vendedor(sellers: pd.DataFrame, geo: pd.DataFrame) -> pd.DataFrame:
    s = _limpiar_ids(sellers.copy(), ["seller_id"])
    s = s.dropna(subset=["seller_id"]).drop_duplicates("seller_id")
    dim = pd.concat([s[["seller_id"]],
                     _ubicacion(s, "seller_zip_code_prefix", "seller_city", "seller_state", geo)], axis=1)
    log.info("  DIM_VENDEDOR: %s vendedores", fmt(len(dim)))
    return dim.reset_index(drop=True)


def _rango_peso(peso: pd.Series) -> pd.Series:
    """R10: clasificación logística por peso."""
    cond = [peso.isna(), peso < 500, peso < 2000, peso < 10000]
    etiquetas = ["Sin dato", "Ligero (<0.5kg)", "Medio (0.5-2kg)", "Pesado (2-10kg)"]
    return pd.Series(np.select([c.fillna(False).to_numpy(dtype=bool) for c in cond], etiquetas,
                               default="Muy pesado (>10kg)"), index=peso.index)


def dim_producto(products: pd.DataFrame, traduccion: pd.DataFrame) -> pd.DataFrame:
    p = _limpiar_ids(products.copy(), ["product_id"])
    p = p.dropna(subset=["product_id"]).drop_duplicates("product_id")

    p["categoria_pt"] = normalizar_texto(p["product_category_name"])
    sin_cat = int(p["categoria_pt"].isna().sum())
    p["categoria_pt"] = p["categoria_pt"].fillna("sin_categoria")  # R07

    t = traduccion.copy()
    t["categoria_pt"] = normalizar_texto(t["product_category_name"])
    t = t.drop_duplicates("categoria_pt")
    p = p.merge(t[["categoria_pt", "product_category_name_english"]], on="categoria_pt", how="left")
    faltantes = p.loc[p["product_category_name_english"].isna(), "categoria_pt"].unique()
    p["categoria_en"] = (p["product_category_name_english"]
                         .fillna(p["categoria_pt"].map(TRADUCCION_CATEGORIAS_FALTANTES))
                         .fillna(p["categoria_pt"]))  # R08

    medidas = {"product_weight_g": "peso_g", "product_length_cm": "largo_cm",
               "product_height_cm": "alto_cm", "product_width_cm": "ancho_cm",
               "product_photos_qty": "cantidad_fotos"}
    for origen, destino in medidas.items():  # R09: negativos no son válidos -> nulo
        valor = pd.to_numeric(p[origen], errors="coerce")
        p[destino] = valor.where(valor >= 0).round().astype("Int64")
    p["volumen_cm3"] = (p["largo_cm"] * p["alto_cm"] * p["ancho_cm"]).astype("Int64")
    p["rango_peso"] = _rango_peso(p["peso_g"])

    log.info("  DIM_PRODUCTO: %s productos (%s sin categoría; traducción manual para: %s)",
             fmt(len(p)), fmt(sin_cat), ", ".join(sorted(faltantes)) or "ninguna")
    return p[["product_id", "categoria_pt", "categoria_en", "peso_g", "largo_cm", "alto_cm",
              "ancho_cm", "volumen_cm3", "rango_peso", "cantidad_fotos"]].reset_index(drop=True)


def dim_estado_orden(orders: pd.DataFrame) -> pd.DataFrame:
    estados = normalizar_texto(orders["order_status"]).dropna().unique()
    dim = pd.DataFrame({"estado_orden": sorted(estados)})
    dim["estado_orden_es"] = dim["estado_orden"].map(ESTADOS_ORDEN).fillna(dim["estado_orden"].str.capitalize())
    dim["es_completada"] = np.where(dim["estado_orden"] == "delivered", "Sí", "No")
    return dim


def dim_tipo_pago(payments: pd.DataFrame) -> pd.DataFrame:
    tipos = normalizar_texto(payments["payment_type"]).dropna().unique()
    dim = pd.DataFrame({"tipo_pago": sorted(tipos)})
    dim["tipo_pago_es"] = dim["tipo_pago"].map(TIPOS_PAGO).fillna(dim["tipo_pago"].str.capitalize())
    return dim


def dim_tiempo(orders: pd.DataFrame) -> pd.DataFrame:
    """R12: calendario continuo desde la primera hasta la última fecha de las órdenes."""
    cols = ["order_purchase_timestamp", "order_approved_at", "order_delivered_carrier_date",
            "order_delivered_customer_date", "order_estimated_delivery_date"]
    fechas = pd.concat([orders[c] for c in cols]).dropna()
    rango = pd.date_range(fechas.min().normalize(), fechas.max().normalize(), freq="D")
    d = pd.DataFrame({"fecha": rango})
    d["sk_tiempo"] = d["fecha"].dt.year * 10000 + d["fecha"].dt.month * 100 + d["fecha"].dt.day
    d["anio"] = d["fecha"].dt.year
    d["trimestre"] = d["fecha"].dt.quarter
    d["mes"] = d["fecha"].dt.month
    d["nombre_mes"] = d["mes"].map(lambda m: MESES[m - 1])
    d["anio_mes"] = d["fecha"].dt.strftime("%Y-%m")
    d["dia"] = d["fecha"].dt.day
    d["dia_semana"] = d["fecha"].dt.dayofweek + 1
    d["nombre_dia"] = d["dia_semana"].map(lambda x: DIAS[x - 1])
    d["es_fin_semana"] = np.where(d["dia_semana"] >= 6, "Sí", "No")
    log.info("  DIM_TIEMPO: %s días (%s a %s)", fmt(len(d)), rango.min().date(), rango.max().date())
    return d[["sk_tiempo", "fecha", "anio", "trimestre", "mes", "nombre_mes", "anio_mes",
              "dia", "dia_semana", "nombre_dia", "es_fin_semana"]]


# ---------------------------------------------------------------------------
# Hechos
# ---------------------------------------------------------------------------
def preparar_ordenes(orders: pd.DataFrame, customers: pd.DataFrame) -> pd.DataFrame:
    """Orden + cliente real (customer_unique_id) + estado normalizado."""
    o = _limpiar_ids(orders.copy(), ["order_id", "customer_id"])
    o["estado_orden"] = normalizar_texto(o["order_status"])
    c = _limpiar_ids(customers[["customer_id", "customer_unique_id"]].copy(), ["customer_id", "customer_unique_id"])
    return o.merge(c.drop_duplicates("customer_id"), on="customer_id", how="left")


def review_por_orden(reviews: pd.DataFrame) -> pd.DataFrame:
    """R13: una puntuación por orden (la reseña respondida más recientemente)."""
    r = _limpiar_ids(reviews.copy(), ["order_id"])
    r["review_score"] = pd.to_numeric(r["review_score"], errors="coerce")
    validas = r["order_id"].notna() & r["review_score"].between(1, 5)
    guardar_rechazados(r[~validas], "reviews", "order_id nulo o puntuación fuera de 1-5")
    r = (r[validas]
         .sort_values(["review_answer_timestamp", "review_creation_date"], ascending=False, na_position="last")
         .drop_duplicates("order_id", keep="first"))
    log.info("  Reseñas: %s filas -> %s órdenes con puntuación", fmt(len(reviews)), fmt(len(r)))
    return r[["order_id", "review_score"]]


def fact_ventas(items: pd.DataFrame, ordenes: pd.DataFrame, reviews: pd.DataFrame,
                claves: dict[str, pd.Series], fechas_validas: set[int]) -> pd.DataFrame:
    v = _limpiar_ids(items.copy(), ["order_id", "product_id", "seller_id"])
    v["price"] = pd.to_numeric(v["price"], errors="coerce")
    v["freight_value"] = pd.to_numeric(v["freight_value"], errors="coerce")

    # R14: precio y flete obligatorios y no negativos
    invalidos = v["price"].isna() | (v["price"] < 0) | v["freight_value"].isna() | (v["freight_value"] < 0)
    guardar_rechazados(v[invalidos], "fact_ventas", "precio o flete nulo o negativo")
    v = v[~invalidos]

    duplicados = v.duplicated(["order_id", "order_item_id"], keep="first")
    guardar_rechazados(v[duplicados], "fact_ventas", "ítem duplicado (order_id, order_item_id)")
    v = v[~duplicados]

    v = v.merge(ordenes, on="order_id", how="left", indicator=True)
    huerfanos = v["_merge"] == "left_only"
    guardar_rechazados(v.loc[huerfanos, items.columns], "fact_ventas", "ítem sin orden en STG_ORDERS")
    v = v[~huerfanos].drop(columns="_merge")
    v = v.merge(reviews, on="order_id", how="left")

    compra = v["order_purchase_timestamp"]
    entrega = v["order_delivered_customer_date"]
    estimada = v["order_estimated_delivery_date"]

    # R15: medidas de entrega; fechas imposibles -> medida nula (no se inventa un valor)
    dias_entrega = (entrega - compra).dt.days
    v["dias_entrega"] = dias_entrega.where(dias_entrega >= 0).astype("Int64")
    v["dias_atraso"] = (entrega.dt.normalize() - estimada.dt.normalize()).dt.days.astype("Int64")
    v["entregado_a_tiempo"] = (entrega.dt.normalize() <= estimada.dt.normalize()).astype("Int64")
    v.loc[entrega.isna() | estimada.isna(), "entregado_a_tiempo"] = pd.NA

    f = pd.DataFrame({
        "order_id": v["order_id"],
        "order_item_id": v["order_item_id"].astype("int64"),
        "sk_fecha_compra": _sk_fecha(compra, fechas_validas),
        "sk_fecha_entrega": _sk_fecha(entrega, fechas_validas),
        "sk_cliente": _mapear(v["customer_unique_id"], claves["cliente"]),
        "sk_producto": _mapear(v["product_id"], claves["producto"]),
        "sk_vendedor": _mapear(v["seller_id"], claves["vendedor"]),
        "sk_estado_orden": _mapear(v["estado_orden"], claves["estado_orden"]),
        "cantidad": 1,
        "precio": v["price"].round(2),
        "flete": v["freight_value"].round(2),
        "monto_total": (v["price"] + v["freight_value"]).round(2),
        "dias_entrega": v["dias_entrega"],
        "dias_atraso": v["dias_atraso"],
        "entregado_a_tiempo": v["entregado_a_tiempo"],
        "review_score": v["review_score"].round().astype("Int64"),
    }).reset_index(drop=True)
    _avisar_desconocidos(f, "FACT_VENTAS", ["sk_fecha_compra", "sk_cliente", "sk_producto",
                                            "sk_vendedor", "sk_estado_orden"])
    log.info("  FACT_VENTAS: %s filas listas", fmt(len(f)))
    return f


def fact_pagos(payments: pd.DataFrame, ordenes: pd.DataFrame,
               claves: dict[str, pd.Series], fechas_validas: set[int]) -> pd.DataFrame:
    p = _limpiar_ids(payments.copy(), ["order_id"])
    p["payment_value"] = pd.to_numeric(p["payment_value"], errors="coerce")
    p["tipo_pago"] = normalizar_texto(p["payment_type"])

    invalidos = p["payment_value"].isna() | (p["payment_value"] < 0)
    guardar_rechazados(p[invalidos], "fact_pagos", "monto nulo o negativo")
    p = p[~invalidos]

    duplicados = p.duplicated(["order_id", "payment_sequential"], keep="first")
    guardar_rechazados(p[duplicados], "fact_pagos", "pago duplicado (order_id, payment_sequential)")
    p = p[~duplicados]

    p = p.merge(ordenes, on="order_id", how="left", indicator=True)
    huerfanos = p["_merge"] == "left_only"
    guardar_rechazados(p.loc[huerfanos, payments.columns], "fact_pagos", "pago sin orden en STG_ORDERS")
    p = p[~huerfanos]

    # R16: 0 cuotas no existe en la práctica -> pago de contado (1 cuota)
    cuotas = pd.to_numeric(p["payment_installments"], errors="coerce").astype("Int64")
    cero = int((cuotas == 0).sum())
    if cero:
        log.info("  FACT_PAGOS: %s pagos con 0 cuotas -> 1 (regla R16)", fmt(cero))
    cuotas = cuotas.mask(cuotas == 0, 1)

    f = pd.DataFrame({
        "order_id": p["order_id"],
        "payment_sequential": p["payment_sequential"].astype("int64"),
        "sk_fecha_compra": _sk_fecha(p["order_purchase_timestamp"], fechas_validas),
        "sk_cliente": _mapear(p["customer_unique_id"], claves["cliente"]),
        "sk_tipo_pago": _mapear(p["tipo_pago"], claves["tipo_pago"]),
        "sk_estado_orden": _mapear(p["estado_orden"], claves["estado_orden"]),
        "cuotas": cuotas,
        "monto_pago": p["payment_value"].round(2),
    }).reset_index(drop=True)
    _avisar_desconocidos(f, "FACT_PAGOS", ["sk_fecha_compra", "sk_cliente", "sk_tipo_pago", "sk_estado_orden"])
    log.info("  FACT_PAGOS: %s filas listas", fmt(len(f)))
    return f
