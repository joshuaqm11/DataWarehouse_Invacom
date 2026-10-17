# Reglas de transformación del ETL

Cada regla tiene un código que aparece como comentario en `etl/transform.py`. Las filas que no pueden cargarse se guardan en `logs/rechazados_<destino>_<fecha>.csv` con el motivo; nada se descarta en silencio.

| Código | Problema detectado en la fuente | Regla aplicada | Dónde |
|---|---|---|---|
| R01 | Claves de texto con espacios o vacías | `strip()`; cadena vacía → nulo | Todas las tablas |
| R02 | Códigos postales con posible pérdida de ceros | Rellenar a 5 dígitos (`zfill(5)`) | Cliente, vendedor, geolocalización |
| R03 | Ciudades con tildes, mayúsculas y espacios inconsistentes (`São Paulo`, `sao paulo `) | Minúsculas, sin tildes, espacios simples | Cliente, vendedor |
| R04 | `STG_GEOLOCATION` repite cada código postal muchas veces (1,000,163 filas) y tiene coordenadas fuera de Brasil | Se descartan coordenadas fuera del rectángulo de Brasil y se deja **una fila por código postal** con latitud y longitud promedio | Geolocalización |
| R05 | El estado (UF) no dice la región | Enriquecimiento: UF → región oficial del IBGE (Norte, Nordeste, Centro-Oeste, Sudeste, Sur) | Cliente, vendedor |
| R06 | `customer_id` cambia en cada orden; la persona real es `customer_unique_id` | Una fila por `customer_unique_id`. Si tuvo varias direcciones, se toma la de su orden más reciente (SCD tipo 1) | DIM_CLIENTE |
| R07 | Productos sin categoría | Categoría `sin_categoria` | DIM_PRODUCTO |
| R08 | Categorías sin traducción al inglés (`pc_gamer`, `portateis_cozinha_e_preparadores_de_alimentos`) | Traducción manual en el catálogo `TRADUCCION_CATEGORIAS_FALTANTES` | DIM_PRODUCTO |
| R09 | Peso o medidas nulas o negativas | Nulo (no se inventa un valor) | DIM_PRODUCTO |
| R10 | Peso sin agrupar | Enriquecimiento: rango de peso (Ligero, Medio, Pesado, Muy pesado, Sin dato) y volumen = largo × alto × ancho | DIM_PRODUCTO |
| R11 | Estados y tipos de pago en inglés | Traducción al español para los informes | DIM_ESTADO_ORDEN, DIM_TIPO_PAGO |
| R12 | No existe calendario en la fuente | Calendario continuo generado desde la primera hasta la última fecha de las órdenes | DIM_TIEMPO |
| R13 | Órdenes con varias reseñas y `review_id` repetidos | Una puntuación por orden: la reseña respondida más recientemente. Puntuaciones fuera de 1–5 se rechazan | FACT_VENTAS |
| R14 | Posibles precios o fletes nulos o negativos | Se rechaza el ítem | FACT_VENTAS |
| R15 | Órdenes sin fecha de entrega (canceladas, en camino) o con fechas imposibles | Medidas de días y "a tiempo" quedan en nulo; la fecha de entrega apunta a `-1 Sin fecha` | FACT_VENTAS |
| R16 | Pagos con 0 cuotas | Se interpretan como pago de contado: 1 cuota | FACT_PAGOS |
| R17 | Hechos cuyo producto, vendedor, cliente o estado no existe en la dimensión | Se cargan apuntando al miembro `-1 Desconocido` (se informa la cantidad en la bitácora) | Ambos hechos |
| R18 | Ítems o pagos duplicados por su clave, o sin orden en `STG_ORDERS` | Se rechazan y se guardan en el archivo de rechazados | Ambos hechos |

## Estrategia de carga

- **Dimensiones:** `MERGE` por clave natural (actualiza si existe, inserta si no). Las claves sustitutas se mantienen estables entre ejecuciones.
- **Hechos:** recarga completa (`DELETE` + `INSERT`) en la **misma transacción** que las dimensiones. Si cualquier paso falla se hace `ROLLBACK` y el DW queda exactamente como estaba.
- Ejecutar el ETL varias veces **no duplica datos** (lo comprueba la validación).

## Validación automática (`etl/validar.py`)

Compara la fuente con el DW: conteos de ítems, pagos, órdenes, clientes reales, productos y vendedores; sumas de precio, flete y pagos con tolerancia de 0.01 BRL. Revisa también duplicados en las llaves de los hechos, hechos apuntando a `-1` y coherencia entre medidas.
