"""Configuración y conexiones del ETL.

Lee las credenciales desde etl/.env (no versionado) y expone dos engines:
- engine_fuente(): esquema con las tablas STG_* (solo lectura)
- engine_dw():     esquema DW_INVACOM (destino)

Usa python-oracledb en modo "thin": no requiere instalar Oracle Instant Client.
"""
import os
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.engine import Engine, URL

load_dotenv(Path(__file__).with_name(".env"))


def _engine(user_var: str, pwd_var: str) -> Engine:
    faltantes = [v for v in ("DB_HOST", "DB_PORT", "DB_SERVICE", user_var, pwd_var) if not os.getenv(v)]
    if faltantes:
        raise RuntimeError(f"Faltan variables en etl/.env: {', '.join(faltantes)}")

    url = URL.create(
        "oracle+oracledb",
        username=os.environ[user_var],
        password=os.environ[pwd_var],
        host=os.environ["DB_HOST"],
        port=int(os.environ["DB_PORT"]),
        query={"service_name": os.environ["DB_SERVICE"]},
    )
    return create_engine(url, pool_pre_ping=True)


def engine_fuente() -> Engine:
    return _engine("SRC_USER", "SRC_PASSWORD")


def engine_dw() -> Engine:
    return _engine("DW_USER", "DW_PASSWORD")
