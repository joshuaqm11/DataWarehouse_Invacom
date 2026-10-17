"""Utilidades comunes del ETL: bitácora, normalización de texto y registro de rechazos."""
import logging
import sys
import unicodedata
from datetime import datetime
from pathlib import Path

import pandas as pd

RAIZ = Path(__file__).resolve().parent.parent
DIR_LOGS = RAIZ / "logs"
ID_EJECUCION = datetime.now().strftime("%Y%m%d_%H%M%S")

log = logging.getLogger("etl")

# Acumula las filas rechazadas por destino durante la ejecución (para la bitácora)
RECHAZOS: dict[str, int] = {}


def configurar_log() -> Path:
    """Muestra la bitácora en consola y la guarda en logs/etl_<fecha>.log."""
    DIR_LOGS.mkdir(exist_ok=True)
    archivo = DIR_LOGS / f"etl_{ID_EJECUCION}.log"
    try:
        sys.stdout.reconfigure(encoding="utf-8")  # tildes en la consola de Windows
    except AttributeError:
        pass
    formato = logging.Formatter("%(asctime)s | %(levelname)-7s | %(message)s", "%H:%M:%S")
    log.setLevel(logging.INFO)
    log.handlers.clear()
    for handler in (logging.StreamHandler(sys.stdout), logging.FileHandler(archivo, encoding="utf-8")):
        handler.setFormatter(formato)
        log.addHandler(handler)
    return archivo


def _sin_tildes(texto: str) -> str:
    descompuesto = unicodedata.normalize("NFKD", texto)
    return "".join(c for c in descompuesto if not unicodedata.combining(c))


def normalizar_texto(serie: pd.Series) -> pd.Series:
    """minúsculas, sin tildes, sin espacios repetidos ni en los extremos.

    'São Paulo ' -> 'sao paulo'. Se calcula una vez por valor distinto
    (la geolocalización tiene 1 millón de filas pero pocas ciudades).
    """
    s = serie.astype("string")
    distintos = s.dropna().unique()
    mapa = {v: " ".join(_sin_tildes(v).lower().split()) for v in distintos}
    return s.map(mapa).astype("string")


def guardar_rechazados(df: pd.DataFrame, nombre: str, motivo: str) -> int:
    """Guarda filas no cargadas en logs/rechazados_<nombre>.csv con su motivo."""
    if df.empty:
        return 0
    DIR_LOGS.mkdir(exist_ok=True)
    salida = df.copy()
    salida["motivo_rechazo"] = motivo
    archivo = DIR_LOGS / f"rechazados_{nombre}_{ID_EJECUCION}.csv"
    salida.to_csv(archivo, mode="a", index=False, header=not archivo.exists(), encoding="utf-8")
    RECHAZOS[nombre] = RECHAZOS.get(nombre, 0) + len(df)
    log.warning("  %s: %s filas rechazadas (%s) -> %s", nombre, f"{len(df):,}", motivo, archivo.name)
    return len(df)


def fmt(n: int) -> str:
    return f"{n:,}"
