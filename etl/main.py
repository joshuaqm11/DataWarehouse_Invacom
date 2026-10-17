"""Punto de entrada del ETL (se completa en el Sprint 2).

Flujo previsto:
    1. extract   -> leer tablas STG_* necesarias       (extract.py,   Joseph)
    2. transform -> limpiar y construir dims y hechos  (transform.py, Joseph / Fabio)
    3. load      -> cargar dims, resolver claves, hechos (load.py,    Joseph / Fabio)
    4. validar   -> conteos, duplicados, claves, medidas (sql/validacion, Fabio)
    5. resumen   -> filas leídas / cargadas / rechazadas y duración

Ejecutar desde la raíz del repo:  python etl/main.py
"""


def main() -> None:
    raise NotImplementedError("El ETL se implementa en el Sprint 2.")


if __name__ == "__main__":
    main()
