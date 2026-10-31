# Registro de calidad de datos — fuente Olist

Responsable: Fernanda · Consultas: `sql/exploracion/02_perfilado_calidad.sql`

Completar la columna **Resultado** al ejecutar cada consulta. La columna **Tratamiento** se acuerda en equipo antes de programar el ETL (la regla debe poder defenderse ante el jurado).

| # | Control | Tabla | Resultado | Tratamiento propuesto |
|---|---|---|---|---|
| 1.1 | Claves duplicadas | ORDERS, CUSTOMERS, PRODUCTS, SELLERS, ORDER_ITEMS | 0 duplicados en las 5 tablas | |
| 1.2 | customer_id vs customer_unique_id | CUSTOMERS | 99,441 customer_id → 96,096 clientes reales | La dimensión cliente se construye por `customer_unique_id` |
| 1.3 | review_id repetidos / órdenes con varias reviews | ORDER_REVIEWS | 99,224 filas; 98,410 review_id distintos; 98,673 órdenes con review; 547 órdenes con varias reviews | |
| 1.4 | Filas por código postal | GEOLOCATION | 1,000,163 filas → 19,015 zips distintos (~53 filas por zip) | Una fila por zip (ciudad/estado más frecuente, coordenadas promedio) |
| 2.1 | Productos sin categoría / medidas | PRODUCTS | 610 sin categoría; 2 sin peso; 2 sin medidas | Categoría → `sin_categoria`; medidas nulas se conservan como NULL |
| 2.2 | Fechas nulas según estado | ORDERS | delivered: 14 sin aprobación, 2 sin envío, 8 sin entrega. Sin fecha de entrega por estado: shipped 1,107; canceled 619; unavailable 609; invoiced 314; processing 301; created 5; approved 2 | |
| 2.3 | Reviews sin comentario | ORDER_REVIEWS | 58,247 sin mensaje (58.7%); 87,656 sin título (88.3%) de 99,224 | No aplica al DW (texto libre fuera del alcance) |
| 3 | Huérfanos (cada línea del UNION) | varias | 0 en todos los controles excepto: 775 órdenes sin ítems, 1 orden sin pago, 157 zips de clientes sin geolocalización | Clave `-1 Desconocido` en la dimensión |
| 3.1 | Categorías sin traducción | PRODUCTS / TRANSLATION | 2 (`pc_gamer`, `portateis_cozinha_e_preparadores_de_alimentos`) | Traducción manual documentada |
| 4.1 | Ciudades con distinta escritura | GEOLOCATION / CUSTOMERS / SELLERS | Ej.: "sao paulo" 135,800; "são paulo" 24,918; "sãopaulo" 2; "sao paulo das missoes" / "são paulo das missões" | Minúsculas, sin tildes, sin espacios dobles |
| 4.2 | Valores de estado / tipo de pago / UF | ORDERS / PAYMENTS /