-- =====================================================================
-- 02_perfilado_calidad.sql  ·  Responsable: Fernanda
-- Ejecutar con la conexión del esquema fuente, consulta por consulta
-- (Ctrl+Enter) y anotar el resultado en docs/calidad_datos.md.
-- Cada bloque = un control de la guía: nulos, duplicados, formato,
-- integridad referencial y valores atípicos.
-- =====================================================================

------------------------------------------------------------
-- 1. DUPLICADOS
------------------------------------------------------------
-- 1.1 Claves duplicadas (todas deberían dar 0 filas)
SELECT order_id, COUNT(*) FROM STG_ORDERS GROUP BY order_id HAVING COUNT(*) > 1;
SELECT customer_id, COUNT(*) FROM STG_CUSTOMERS GROUP BY customer_id HAVING COUNT(*) > 1;
SELECT product_id, COUNT(*) FROM STG_PRODUCTS GROUP BY product_id HAVING COUNT(*) > 1;
SELECT seller_id, COUNT(*) FROM STG_SELLERS GROUP BY seller_id HAVING COUNT(*) > 1;
SELECT order_id, order_item_id, COUNT(*) FROM STG_ORDER_ITEMS
GROUP BY order_id, order_item_id HAVING COUNT(*) > 1;

-- 1.2 Clientes: customer_id (por orden) vs customer_unique_id (persona real)
SELECT COUNT(*) AS customer_ids,
       COUNT(DISTINCT customer_unique_id) AS clientes_reales
FROM STG_CUSTOMERS;

-- 1.3 Reviews: review_id repetidos y órdenes con más de una review
SELECT COUNT(*) AS filas, COUNT(DISTINCT review_id) AS review_ids,
       COUNT(DISTINCT order_id) AS ordenes_con_review
FROM STG_ORDER_REVIEWS;

SELECT COUNT(*) AS ordenes_con_varias_reviews FROM (
  SELECT order_id FROM STG_ORDER_REVIEWS GROUP BY order_id HAVING COUNT(*) > 1);

-- 1.4 Geolocalización: filas por código postal (duplicación masiva)
SELECT COUNT(*) AS filas,
       COUNT(DISTINCT geolocation_zip_code_prefix) AS zips_distintos
FROM STG_GEOLOCATION;

------------------------------------------------------------
-- 2. NULOS
------------------------------------------------------------
-- 2.1 Productos sin categoría y sin medidas
SELECT SUM(CASE WHEN product_category_name IS NULL THEN 1 ELSE 0 END) AS sin_categoria,
       SUM(CASE WHEN product_weight_g IS NULL THEN 1 ELSE 0 END)      AS sin_peso,
       SUM(CASE WHEN product_length_cm IS NULL
                 OR product_height_cm IS NULL
                 OR product_width_cm IS NULL THEN 1 ELSE 0 END)       AS sin_medidas
FROM STG_PRODUCTS;

-- 2.2 Fechas nulas en órdenes, cruzado con su estado
SELECT order_status,
       COUNT(*) AS ordenes,
       SUM(CASE WHEN order_approved_at IS NULL THEN 1 ELSE 0 END)             AS sin_aprobacion,
       SUM(CASE WHEN order_delivered_carrier_date IS NULL THEN 1 ELSE 0 END)  AS sin_envio,
       SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS sin_entrega
FROM STG_ORDERS
GROUP BY order_status
ORDER BY ordenes DESC;

-- 2.3 Reviews sin comentario
SELECT SUM(CASE WHEN review_comment_message IS NULL THEN 1 ELSE 0 END) AS sin_mensaje,
       SUM(CASE WHEN review_comment_title IS NULL THEN 1 ELSE 0 END)   AS sin_titulo,
       COUNT(*) AS total
FROM STG_ORDER_REVIEWS;

------------------------------------------------------------
-- 3. INTEGRIDAD REFERENCIAL (huérfanos)
------------------------------------------------------------
SELECT 'items sin orden' control, COUNT(*) FROM STG_ORDER_ITEMS i
 WHERE NOT EXISTS (SELECT 1 FROM STG_ORDERS o WHERE o.order_id = i.order_id) UNION ALL
SELECT 'items sin producto', COUNT(*) FROM STG_ORDER_ITEMS i
 WHERE NOT EXISTS (SELECT 1 FROM STG_PRODUCTS p WHERE p.product_id = i.product_id) UNION ALL
SELECT 'items sin vendedor', COUNT(*) FROM STG_ORDER_ITEMS i
 WHERE NOT EXISTS (SELECT 1 FROM STG_SELLERS s WHERE s.seller_id = i.seller_id) UNION ALL
SELECT 'ordenes sin cliente', COUNT(*) FROM STG_ORDERS o
 WHERE NOT EXISTS (SELECT 1 FROM STG_CUSTOMERS c WHERE c.customer_id = o.customer_id) UNION ALL
SELECT 'ordenes sin items', COUNT(*) FROM STG_ORDERS o
 WHERE NOT EXISTS (SELECT 1 FROM STG_ORDER_ITEMS i WHERE i.order_id = o.order_id) UNION ALL
SELECT 'ordenes sin pago', COUNT(*) FROM STG_ORDERS o
 WHERE NOT EXISTS (SELECT 1 FROM STG_ORDER_PAYMENTS p WHERE p.order_id = o.order_id) UNION ALL
SELECT 'pagos sin orden', COUNT(*) FROM STG_ORDER_PAYMENTS p
 WHERE NOT EXISTS (SELECT 1 FROM STG_ORDERS o WHERE o.order_id = p.order_id) UNION ALL
SELECT 'reviews sin orden', COUNT(*) FROM STG_ORDER_REVIEWS r
 WHERE NOT EXISTS (SELECT 1 FROM STG_ORDERS o WHERE o.order_id = r.order_id) UNION ALL
SELECT 'categorias sin traduccion', COUNT(DISTINCT p.product_category_name) FROM STG_PRODUCTS p
 WHERE p.product_category_name IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM STG_PRODUCT_CATEGORY_TRANSLATION t
                   WHERE t.product_category_name = p.product_category_name) UNION ALL
SELECT 'zips de clientes sin geolocalizacion', COUNT(DISTINCT c.customer_zip_code_prefix) FROM STG_CUSTOMERS c
 WHERE NOT EXISTS (SELECT 1 FROM STG_GEOLOCATION g
                   WHERE g.geolocation_zip_code_prefix = c.customer_zip_code_prefix);

-- 3.1 Cuáles categorías no tienen traducción
SELECT DISTINCT p.product_category_name
FROM STG_PRODUCTS p
WHERE p.product_category_name IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM STG_PRODUCT_CATEGORY_TRANSLATION t
                  WHERE t.product_category_name = p.product_category_name);

------------------------------------------------------------
-- 4. FORMATO / CONSISTENCIA
------------------------------------------------------------
-- 4.1 Ciudades escritas de varias formas (tildes, mayúsculas)
SELECT geolocation_city, COUNT(*)
FROM STG_GEOLOCATION
WHERE LOWER(geolocation_city) LIKE '%paulo%'
GROUP BY geolocation_city
ORDER BY 2 DESC;

-- 4.2 Valores posibles de campos categóricos
SELECT order_status, COUNT(*) FROM STG_ORDERS GROUP BY order_status ORDER BY 2 DESC;
SELECT payment_type, COUNT(*) FROM STG_ORDER_PAYMENTS GROUP BY payment_type ORDER BY 2 DESC;
SELECT customer_state, COUNT(*) FROM STG_CUSTOMERS GROUP BY customer_state ORDER BY 2 DESC;

------------------------------------------------------------
-- 5. VALORES ATÍPICOS / INCOHERENTES
------------------------------------------------------------
-- 5.1 Precios, fletes y pagos en cero o negativos
SELECT SUM(CASE WHEN price <= 0 THEN 1 ELSE 0 END)         AS precio_cero_neg,
       SUM(CASE WHEN freight_value < 0 THEN 1 ELSE 0 END)  AS flete_negativo,
       SUM(CASE WHEN freight_value = 0 THEN 1 ELSE 0 END)  AS flete_gratis,
       MIN(price), MAX(price), ROUND(AVG(price), 2) AS precio_prom
FROM STG_ORDER_ITEMS;

SELECT SUM(CASE WHEN payment_value = 0 THEN 1 ELSE 0 END)        AS pagos_en_cero,
       SUM(CASE WHEN payment_installments = 0 THEN 1 ELSE 0 END) AS cuotas_en_cero,
       MAX(payment_installments) AS max_cuotas
FROM STG_ORDER_PAYMENTS;

-- 5.2 Secuencia de fechas imposible
SELECT
  SUM(CASE WHEN order_approved_at < order_purchase_timestamp THEN 1 ELSE 0 END)               AS aprobada_antes_compra,
  SUM(CASE WHEN order_delivered_carrier_date < order_purchase_timestamp THEN 1 ELSE 0 END)    AS enviada_antes_compra,
  SUM(CASE WHEN order_delivered_customer_date < order_delivered_carrier_date THEN 1 ELSE 0 END) AS entregada_antes_envio,
  SUM(CASE WHEN order_status = 'delivered' AND order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS entregada_sin_fecha
FROM STG_ORDERS;

-- 5.3 Cuadre: pago total de la orden vs. (precio + flete) de sus ítems
SELECT COUNT(*) AS ordenes_descuadradas FROM (
  SELECT i.order_id, SUM(i.price + i.freight_value) AS total_items, p.total_pagado
  FROM STG_ORDER_ITEMS i
  JOIN (SELECT order_id, SUM(payment_value) total_pagado
        FROM STG_ORDER_PAYMENTS GROUP BY order_id) p ON p.order_id = i.order_id
  GROUP BY i.order_id, p.total_pagado
  HAVING ABS(SUM(i.price + i.freight_value) - p.total_pagado) > 1
);
