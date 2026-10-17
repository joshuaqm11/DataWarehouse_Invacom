-- =====================================================================
-- 01_validaciones_dw.sql · Controles después de ejecutar el ETL
-- EJECUTAR: con la conexión DW_INVACOM (Ctrl+Enter por consulta).
-- Útil para la demostración ante el jurado.
-- =====================================================================

-- 1. Conteo por tabla
SELECT 'DIM_TIEMPO' tabla, COUNT(*) filas FROM DIM_TIEMPO UNION ALL
SELECT 'DIM_CLIENTE', COUNT(*) FROM DIM_CLIENTE UNION ALL
SELECT 'DIM_VENDEDOR', COUNT(*) FROM DIM_VENDEDOR UNION ALL
SELECT 'DIM_PRODUCTO', COUNT(*) FROM DIM_PRODUCTO UNION ALL
SELECT 'DIM_ESTADO_ORDEN', COUNT(*) FROM DIM_ESTADO_ORDEN UNION ALL
SELECT 'DIM_TIPO_PAGO', COUNT(*) FROM DIM_TIPO_PAGO UNION ALL
SELECT 'FACT_VENTAS', COUNT(*) FROM FACT_VENTAS UNION ALL
SELECT 'FACT_PAGOS', COUNT(*) FROM FACT_PAGOS;

-- 2. Granularidad: no debe haber claves repetidas (esperado: 0 filas)
SELECT order_id, order_item_id, COUNT(*)
FROM FACT_VENTAS GROUP BY order_id, order_item_id HAVING COUNT(*) > 1;

SELECT order_id, payment_sequential, COUNT(*)
FROM FACT_PAGOS GROUP BY order_id, payment_sequential HAVING COUNT(*) > 1;

-- 3. Hechos apuntando a miembros Desconocido (-1)
SELECT SUM(CASE WHEN sk_producto = -1 THEN 1 ELSE 0 END)      AS producto_desc,
       SUM(CASE WHEN sk_vendedor = -1 THEN 1 ELSE 0 END)      AS vendedor_desc,
       SUM(CASE WHEN sk_cliente = -1 THEN 1 ELSE 0 END)       AS cliente_desc,
       SUM(CASE WHEN sk_fecha_entrega = -1 THEN 1 ELSE 0 END) AS sin_fecha_entrega
FROM FACT_VENTAS;

-- 4. Por qué NO se mezclan pagos con ítems: comparar totales por orden
--    (si se unieran, el pago se repetiría por cada ítem)
SELECT COUNT(*) AS ordenes_con_varios_items
FROM (SELECT order_id FROM FACT_VENTAS GROUP BY order_id HAVING COUNT(*) > 1);

-- 5. Ejemplo analítico: ventas por año y región del cliente
SELECT t.anio, c.region,
       COUNT(DISTINCT f.order_id) AS ordenes,
       SUM(f.cantidad)            AS unidades,
       ROUND(SUM(f.monto_total), 2) AS ventas_brl
FROM FACT_VENTAS f
JOIN DIM_TIEMPO t  ON t.sk_tiempo = f.sk_fecha_compra
JOIN DIM_CLIENTE c ON c.sk_cliente = f.sk_cliente
GROUP BY t.anio, c.region
ORDER BY t.anio, ventas_brl DESC;

-- 6. Ejemplo analítico: atraso vs. satisfacción
SELECT CASE WHEN f.entregado_a_tiempo = 1 THEN 'A tiempo' ELSE 'Con atraso' END AS entrega,
       COUNT(*) AS items,
       ROUND(AVG(f.review_score), 2) AS puntuacion_promedio
FROM FACT_VENTAS f
WHERE f.entregado_a_tiempo IS NOT NULL
GROUP BY CASE WHEN f.entregado_a_tiempo = 1 THEN 'A tiempo' ELSE 'Con atraso' END;

-- 7. Bitácora de la última ejecución del ETL
SELECT tabla, filas_leidas, filas_cargadas, filas_rechazadas, estado, duracion_seg, mensaje
FROM ETL_LOG_CARGA
WHERE id_ejecucion = (SELECT MAX(id_ejecucion) FROM ETL_LOG_CARGA)
ORDER BY id_log;
