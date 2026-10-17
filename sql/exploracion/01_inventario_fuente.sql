-- =====================================================================
-- 01_inventario_fuente.sql  ·  Ejecutar con la conexión del esquema fuente
-- Resultados obtenidos el 17/10/2026 (base olist_ecommerce):
--   CUSTOMERS 99,441 · GEOLOCATION 1,000,163 · ORDER_ITEMS 112,650
--   ORDER_PAYMENTS 103,886 · ORDER_REVIEWS 99,224 · ORDERS 99,441
--   PRODUCTS 32,951 · CATEGORY_TRANSLATION 71 · SELLERS 3,095
-- =====================================================================

-- A) Conteo de filas por tabla
SELECT 'CUSTOMERS' tabla, COUNT(*) filas FROM STG_CUSTOMERS UNION ALL
SELECT 'GEOLOCATION', COUNT(*) FROM STG_GEOLOCATION UNION ALL
SELECT 'ORDER_ITEMS', COUNT(*) FROM STG_ORDER_ITEMS UNION ALL
SELECT 'ORDER_PAYMENTS', COUNT(*) FROM STG_ORDER_PAYMENTS UNION ALL
SELECT 'ORDER_REVIEWS', COUNT(*) FROM STG_ORDER_REVIEWS UNION ALL
SELECT 'ORDERS', COUNT(*) FROM STG_ORDERS UNION ALL
SELECT 'PRODUCTS', COUNT(*) FROM STG_PRODUCTS UNION ALL
SELECT 'CATEGORY_TRANSLATION', COUNT(*) FROM STG_PRODUCT_CATEGORY_TRANSLATION UNION ALL
SELECT 'SELLERS', COUNT(*) FROM STG_SELLERS;

-- B) Columnas, tipos y nulabilidad
SELECT table_name, column_name, data_type, data_length, nullable
FROM user_tab_columns
WHERE table_name LIKE 'STG_%'
ORDER BY table_name, column_id;

-- C) Restricciones declaradas (PK / FK)
SELECT table_name, constraint_name, constraint_type, status
FROM user_constraints
WHERE table_name LIKE 'STG_%' AND constraint_type IN ('P', 'R')
ORDER BY table_name, constraint_type;

-- D) Rango temporal de la fuente
SELECT MIN(order_purchase_timestamp) AS primera_compra,
       MAX(order_purchase_timestamp) AS ultima_compra
FROM STG_ORDERS;
