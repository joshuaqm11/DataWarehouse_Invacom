# Registro de calidad de datos — fuente Olist

Responsable: Fernanda · Consultas: `sql/exploracion/02_perfilado_calidad.sql`

Completar la columna **Resultado** al ejecutar cada consulta. La columna **Tratamiento** se acuerda en equipo antes de programar el ETL (la regla debe poder defenderse ante el jurado).

| # | Control | Tabla | Resultado | Tratamiento propuesto |
|---|---|---|---|---|
| 1.1 | Claves duplicadas | ORDERS, CUSTOMERS, PRODUCTS, SELLERS, ORDER_ITEMS | | |
| 1.2 | customer_id vs customer_unique_id | CUSTOMERS | | La dimensión cliente se construye por `customer_unique_id` |
| 1.3 | review_id repetidos / órdenes con varias reviews | ORDER_REVIEWS | | |
| 1.4 | Filas por código postal | GEOLOCATION | | Una fila por zip (ciudad/estado más frecuente, coordenadas promedio) |
| 2.1 | Productos sin categoría / medidas | PRODUCTS | | Categoría → `sin_categoria`; medidas nulas se conservan como NULL |
| 2.2 | Fechas nulas según estado | ORDERS | | |
| 2.3 | Reviews sin comentario | ORDER_REVIEWS | | No aplica al DW (texto libre fuera del alcance) |
| 3 | Huérfanos (cada línea del UNION) | varias | | Clave `-1 Desconocido` en la dimensión |
| 3.1 | Categorías sin traducción | PRODUCTS / TRANSLATION | | Traducción manual documentada |
| 4.1 | Ciudades con distinta escritura | GEOLOCATION / CUSTOMERS / SELLERS | | Minúsculas, sin tildes, sin espacios dobles |
| 4.2 | Valores de estado / tipo de pago / UF | ORDERS / PAYMENTS / CUSTOMERS | | |
| 5.1 | Precios/pagos en cero o negativos | ORDER_ITEMS / PAYMENTS | | |
| 5.2 | Secuencia de fechas imposible | ORDERS | | Se conservan; medidas de días → NULL |
| 5.3 | Pago total ≠ precio + flete | ITEMS vs PAYMENTS | | Se analizan en hechos separados (no se mezclan) |
