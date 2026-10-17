"""Prueba mínima de conexión a la fuente y al DW. Ejecutar: python etl/test_conexion.py"""
from sqlalchemy import text

from config import engine_dw, engine_fuente


def probar(nombre: str, engine, consulta: str) -> None:
    try:
        with engine.connect() as conn:
            valor = conn.execute(text(consulta)).scalar()
        print(f"[OK]    {nombre}: {valor}")
    except Exception as e:  # se muestra el error, sin credenciales
        print(f"[ERROR] {nombre}: {type(e).__name__}: {e}")


if __name__ == "__main__":
    probar("Fuente (filas en STG_ORDERS)", engine_fuente(), "SELECT COUNT(*) FROM STG_ORDERS")
    probar("DW (usuario conectado)", engine_dw(), "SELECT USER FROM dual")
