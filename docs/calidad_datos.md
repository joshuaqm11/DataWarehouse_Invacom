# Registro de calidad de datos — fuente Olist

Responsable: Fernanda · Consultas: `sql/exploracion/02_perfilado_calidad.sql`

Resultados obtenidos al ejecutar cada consulta sobre las tablas `STG_*`. El tratamiento indica la regla del ETL que lo resuelve (código R01–R18 de `docs/reglas_etl.md`, comentado en `etl/transform.py`).

| # | Control | Tabla | Resultado | Tratamiento aplicado |
|---|---|---|---|---|
| 1.1 | Claves duplicadas | ORDERS, CUSTOMERS, PRODUCTS, SELLERS, ORDER_ITEMS | 0 duplicados en las 5 tablas | Si aparecieran, los ítems o pagos duplicados por su clave se rechazan y se guardan en el archivo de rechazados (R18) |
| 1.2 | customer_id vs customer_unique_id | CUSTOMERS | 99,441 customer_id → 96,096 clientes reales | La dimensión cliente se construye por `customer_unique_id`; si tuvo varias direcciones se toma la de su orden más reciente (R06) |
| 1.3 | review_id repetidos / órdenes con varias reviews | ORDER_REVIEWS | 99,224 filas; 98,410 review_id distintos; 98,673 órdenes con review; 547 órdenes con varias reviews | Una puntuación por orden: la reseña respondida más recientemente; puntuaciones fuera de 1–5 se rechazan (R13) |
| 1.4 | Filas por código postal | GEOLOCATION | 1,000,163 filas → 19,015 zips distintos (~53 filas por zip) | Se descartan 42 coordenadas fuera de Brasil y se deja una fila por zip con coordenadas promedio: 19,010 zips (R04) |
| 2.1 | Productos sin categoría / medidas | PRODUCTS | 610 sin categoría; 2 sin peso; 2 sin medidas | Categoría → `sin_categoria` (R07); peso y medidas nulas se conservan como NULL, rango de peso "Sin dato" (R09, R10) |
| 2.2 | Fechas nulas según estado | ORDERS | delivered: 14 sin aprobación, 2 sin envío, 8 sin entrega. Sin fecha de entrega por estado: shipped 1,107; canceled 619; unavailable 609; invoiced 314; processing 301; created 5; approved 2 | Se conservan las órdenes; medidas de días y "a tiempo" quedan en NULL y la fecha de entrega apunta a `-1 Sin fecha` (R15) |
| 2.3 | Reviews sin comentario | ORDER_REVIEWS | 58,247 sin mensaje (58.7%); 87,656 sin título (88.3%) de 99,224 | No aplica al DW (texto libre fuera del alcance); solo se usa la puntuación |
| 3 | Huérfanos (cada línea del UNION) | varias | 0 en todos los controles excepto: 775 órdenes sin ítems, 1 orden sin pago, 157 zips de clientes sin geolocalización | Hechos sin dimensión apuntan a `-1 Desconocido` (R17); ítems o pagos sin orden se rechazan (R18) |
| 3.1 | Categorías sin traducción | PRODUCTS / TRANSLATION | 2 (`pc_gamer`, `portateis_cozinha_e_preparadores_de_alimentos`) | Traducción manual en el catálogo `TRADUCCION_CATEGORIAS_FALTANTES` (R08) |
| 4.1 | Ciudades con distinta escritura | GEOLOCATION / CUSTOMERS / SELLERS | Ej.: "sao paulo" 135,800; "são paulo" 24,918; "sãopaulo" 2; "sao paulo das missoes" / "são paulo das missões" | Minúsculas, sin tildes, espacios simples (R03) |
| 4.2 | Valores de estado / tipo de pago / UF | ORDERS / PAYMENTS / CUSTOMERS | 8 estados (delivered 96,478 … approved 2); 5 tipos de pago (credit_card 76,795; boleto 19,784; voucher 5,775; debit_card 1,529; not_defined 3); UF con más clientes: SP 41,746 | Estados y tipos de pago se traducen al español (R11); la UF se enriquece con la región del IBGE (R05) |
| 5.1 | Precios/pagos en cero o negativos | ORDER_ITEMS / PAYMENTS | 0 precios ≤ 0; 0 fletes negativos; 383 ítems con flete gratis; precio entre 0.85 y 6,735 (prom. 120.65); 9 pagos en 0; 2 pagos con 0 cuotas (máx. 24) | Precios o fletes nulos o negativos se rechazarían (R14); el flete 0 se conserva (envío gratis); pagos con 0 cuotas → 1 cuota (R16) |
| 5.2 | Secuencia de fechas imposible | ORDERS | 0 aprobadas antes de la compra; 166 enviadas antes de la compra; 23 entregadas antes del envío; 8 entregadas sin fecha | Se conservan las órdenes; medidas de días → NULL (R15) |
| 5.3 | Pago total ≠ precio + flete | ITEMS vs PAYMENTS | 249 órdenes con diferencia mayor a 1 BRL | Ventas y pagos se analizan en hechos separados (`FACT_VENTAS` y `FACT_PAGOS`), no se mezclan |