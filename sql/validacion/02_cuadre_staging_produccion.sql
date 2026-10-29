-- =====================================================================
-- 02_cuadre_staging_produccion.sql
-- Consultas de cuadre y demostracion de deteccion de cambios.
-- Requiere haber ejecutado sql/dw/04_dblinks.sql primero.
--
-- EJECUTAR: SQL Developer · Ctrl+Enter por bloque o F5 como script.
--           Util para la demostracion ante el jurado.
-- =====================================================================

-- Formato de columnas para todos los bloques
COLUMN control    FORMAT A24
COLUMN staging    FORMAT 999,999,999.99
COLUMN produccion FORMAT 999,999,999.99
COLUMN diferencia FORMAT 999,999,999.99
COLUMN tabla      FORMAT A20
COLUMN estado     FORMAT A10
COLUMN ambiente   FORMAT A12
COLUMN precio     FORMAT 999,999.99


-- =====================================================================
-- 1. Cuadre general  (esperado: todo OK, diferencia 0)
-- =====================================================================
SELECT * FROM V_CUADRE_STAGING_PRODUCCION ORDER BY control;


-- =====================================================================
-- 2. Items de staging que NO llegaron a produccion
--    (esperado: 0 filas)
--    Nota: order_item_id es TEXT en staging y NUMBER en el DW;
--          TO_NUMBER evita ORA-01790.
-- =====================================================================
SELECT order_id,
       TO_NUMBER(order_item_id) AS order_item_id,
       price,
       freight_value
FROM  STG_ORDER_ITEMS@LNK_STAGING
MINUS
SELECT order_id, order_item_id, precio, flete
FROM  FACT_VENTAS;


-- =====================================================================
-- 3. Ordenes de staging pendientes de cargar al DW
--    (esperado: 0 filas; ejecutar conectado al usuario staging)
-- =====================================================================
SELECT COUNT(*) AS ordenes_pendientes
FROM (
  SELECT DISTINCT order_id FROM STG_ORDER_ITEMS
  MINUS
  SELECT DISTINCT order_id FROM FACT_VENTAS@LNK_PRODUCCION
);


-- =====================================================================
-- 4. Ultima ejecucion del ETL
--    (esperado: 8 tablas en estado OK; ejecutar conectado al usuario staging)
-- =====================================================================
SELECT id_ejecucion, tabla,
       filas_leidas, filas_cargadas, filas_rechazadas, estado
FROM   ETL_LOG_CARGA@LNK_PRODUCCION
WHERE  id_ejecucion = (SELECT MAX(id_ejecucion)
                       FROM   ETL_LOG_CARGA@LNK_PRODUCCION)
ORDER  BY id_log;


-- =====================================================================
-- 5. Ventas por ano: staging vs. produccion
--    (esperado: diferencia 0 en todos los anos)
--    Nota: segun como se importo el CSV, ORDER_PURCHASE_TIMESTAMP puede ser
--    texto (VARCHAR2) o fecha (DATE/TIMESTAMP). Revisar el tipo con:
--      SELECT data_type FROM user_tab_columns
--      WHERE table_name = 'STG_ORDERS'
--        AND column_name = 'ORDER_PURCHASE_TIMESTAMP';
--    5a = texto (TO_TIMESTAMP evita ORA-30076)  -  5b = DATE/TIMESTAMP.
--    Si con 5a salen anos 1..31, la columna es DATE: usar 5b.
-- =====================================================================
COLUMN ventas_staging    FORMAT 999,999,999.99
COLUMN ventas_produccion FORMAT 999,999,999.99

-- 5a - Fecha de staging como texto
SELECT s.anio,
       s.ventas_staging,
       p.ventas_produccion,
       s.ventas_staging - p.ventas_produccion AS diferencia
FROM (
  SELECT EXTRACT(YEAR FROM TO_TIMESTAMP(o.order_purchase_timestamp,
                                        'YYYY-MM-DD HH24:MI:SS')) anio,
         ROUND(SUM(i.price + i.freight_value), 2)                ventas_staging
  FROM   STG_ORDER_ITEMS  i
  JOIN   STG_ORDERS       o ON o.order_id = i.order_id
  GROUP  BY EXTRACT(YEAR FROM TO_TIMESTAMP(o.order_purchase_timestamp,
                                           'YYYY-MM-DD HH24:MI:SS'))
) s
JOIN (
  SELECT t.anio,
         ROUND(SUM(f.monto_total), 2) ventas_produccion
  FROM   FACT_VENTAS@LNK_PRODUCCION  f
  JOIN   DIM_TIEMPO@LNK_PRODUCCION   t ON t.sk_tiempo = f.sk_fecha_compra
  GROUP  BY t.anio
) p ON p.anio = s.anio
ORDER  BY s.anio;

-- 5b - Misma consulta cuando la fecha de staging es DATE o TIMESTAMP
SELECT s.anio,
       s.ventas_staging,
       p.ventas_produccion,
       s.ventas_staging - p.ventas_produccion AS diferencia
FROM (
  SELECT EXTRACT(YEAR FROM o.order_purchase_timestamp) anio,
         ROUND(SUM(i.price + i.freight_value), 2)      ventas_staging
  FROM   STG_ORDER_ITEMS  i
  JOIN   STG_ORDERS       o ON o.order_id = i.order_id
  GROUP  BY EXTRACT(YEAR FROM o.order_purchase_timestamp)
) s
JOIN (
  SELECT t.anio,
         ROUND(SUM(f.monto_total), 2) ventas_produccion
  FROM   FACT_VENTAS@LNK_PRODUCCION  f
  JOIN   DIM_TIEMPO@LNK_PRODUCCION   t ON t.sk_tiempo = f.sk_fecha_compra
  GROUP  BY t.anio
) p ON p.anio = s.anio
ORDER  BY s.anio;


-- =====================================================================
-- 6. Demostracion de deteccion de cambios  (ejecutar en staging)
-- =====================================================================

-- 6.1  Simular cambio: +100 al precio de un item (NO se confirma)
UPDATE STG_ORDER_ITEMS
SET    price = price + 100
WHERE  order_id      = (SELECT MIN(order_id) FROM STG_ORDER_ITEMS)
  AND  order_item_id = 1;

-- 6.2  El cuadre expone la diferencia:
--      esperado 2 filas, staging con 100 mas que produccion
SELECT 'STAGING'    AS ambiente,
       order_id,
       TO_NUMBER(order_item_id) AS order_item_id,
       price                    AS precio
FROM   STG_ORDER_ITEMS
WHERE  (order_id, TO_NUMBER(order_item_id), price) IN (
         SELECT order_id, TO_NUMBER(order_item_id), price
         FROM   STG_ORDER_ITEMS
         MINUS
         SELECT order_id, order_item_id, precio
         FROM   FACT_VENTAS@LNK_PRODUCCION
       )
UNION ALL
SELECT 'PRODUCCION',
       order_id,
       order_item_id,
       precio
FROM   FACT_VENTAS@LNK_PRODUCCION
WHERE  order_id      = (SELECT MIN(order_id) FROM STG_ORDER_ITEMS)
  AND  order_item_id = 1;

-- 6.3  Deshacer el cambio (obligatorio)
ROLLBACK;

-- 6.4  Verificar que todo vuelve a cuadrar: esperado 0
SELECT COUNT(*) AS diferencias
FROM (
  SELECT order_id, TO_NUMBER(order_item_id), price
  FROM   STG_ORDER_ITEMS
  MINUS
  SELECT order_id, order_item_id, precio
  FROM   FACT_VENTAS@LNK_PRODUCCION
);

-- 6.5  Precio original restaurado en staging
SELECT price AS precio_restaurado
FROM   STG_ORDER_ITEMS
WHERE  order_id      = (SELECT MIN(order_id) FROM STG_ORDER_ITEMS)
  AND  order_item_id = 1;

-- Seguro final: nada queda pendiente en la sesion
ROLLBACK;
