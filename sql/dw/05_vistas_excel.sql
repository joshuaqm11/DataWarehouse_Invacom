-- =====================================================================
-- 04_vistas_excel.sql · Vistas analíticas que consume Excel
-- EJECUTAR: con la conexión DW_INVACOM, como script (F5), después de
--           cargar el DW con el ETL. Se puede re-ejecutar (CREATE OR REPLACE).
--
-- Cada vista une hechos y dimensiones con nombres en español, para que
-- Excel arme las tablas dinámicas sin hacer JOIN. Cada vista respeta UNA
-- granularidad, así ninguna medida se suma dos veces:
--   V_EXCEL_VENTAS   1 fila = 1 ítem vendido       (112,650 filas)
--   V_EXCEL_ORDENES  1 fila = 1 orden con ítems    ( 98,666 filas)
--   V_EXCEL_PAGOS    1 fila = 1 pago de una orden  (103,886 filas)
-- =====================================================================

-- ---------------------------------------------------------------------
-- V_EXCEL_VENTAS · qué se vende, dónde, quién lo vende y cuándo
-- Preguntas 1, 2, 3 y 4. Medidas sumables: Unidades, Precio, Flete, Venta.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW V_EXCEL_VENTAS AS
SELECT
  f.order_id                                   AS "Orden",
  t.fecha                                      AS "Fecha compra",
  t.anio                                       AS "Año",
  'T' || t.trimestre                           AS "Trimestre",
  t.mes                                        AS "Mes",
  t.nombre_mes                                 AS "Nombre mes",
  t.anio_mes                                   AS "Año-Mes",
  t.nombre_dia                                 AS "Día semana",
  p.categoria_en                               AS "Categoría",
  p.categoria_pt                               AS "Categoría (PT)",
  p.rango_peso                                 AS "Rango de peso",
  c.region                                     AS "Región cliente",
  c.estado                                     AS "Estado cliente",
  c.ciudad                                     AS "Ciudad cliente",
  v.region                                     AS "Región vendedor",
  v.estado                                     AS "Estado vendedor",
  v.ciudad                                     AS "Ciudad vendedor",
  'V-' || SUBSTR(v.seller_id, 1, 8)            AS "Vendedor",
  e.estado_orden_es                            AS "Estado orden",
  e.es_completada                              AS "Completada",
  f.cantidad                                   AS "Unidades",
  f.precio                                     AS "Precio BRL",
  f.flete                                      AS "Flete BRL",
  f.monto_total                                AS "Venta BRL"
FROM FACT_VENTAS f
JOIN DIM_TIEMPO t       ON t.sk_tiempo       = f.sk_fecha_compra
JOIN DIM_PRODUCTO p     ON p.sk_producto     = f.sk_producto
JOIN DIM_CLIENTE c      ON c.sk_cliente      = f.sk_cliente
JOIN DIM_VENDEDOR v     ON v.sk_vendedor     = f.sk_vendedor
JOIN DIM_ESTADO_ORDEN e ON e.sk_estado_orden = f.sk_estado_orden;

-- ---------------------------------------------------------------------
-- V_EXCEL_ORDENES · entrega y satisfacción, UNA fila por orden
-- Preguntas 5 y 6. Días de entrega, atraso y reseña son datos de la
-- orden: aquí no se repiten por ítem, así el promedio es correcto.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW V_EXCEL_ORDENES AS
WITH o AS (
  SELECT f.order_id,
         MIN(f.sk_fecha_compra)    AS sk_fecha_compra,
         MIN(f.sk_cliente)         AS sk_cliente,
         MIN(f.sk_estado_orden)    AS sk_estado_orden,
         SUM(f.cantidad)           AS items,
         SUM(f.monto_total)        AS venta,
         MAX(f.dias_entrega)       AS dias_entrega,
         MAX(f.dias_atraso)        AS dias_atraso,
         MAX(f.entregado_a_tiempo) AS a_tiempo,
         MAX(f.review_score)       AS review_score
  FROM FACT_VENTAS f
  GROUP BY f.order_id
)
SELECT
  o.order_id                                   AS "Orden",
  t.anio                                       AS "Año",
  t.anio_mes                                   AS "Año-Mes",
  c.region                                     AS "Región cliente",
  c.estado                                     AS "Estado cliente",
  e.estado_orden_es                            AS "Estado orden",
  o.items                                      AS "Ítems",
  o.venta                                      AS "Venta BRL",
  o.dias_entrega                               AS "Días de entrega",
  o.dias_atraso                                AS "Días de atraso",
  CASE o.a_tiempo WHEN 1 THEN 'A tiempo'
                  WHEN 0 THEN 'Con atraso'
                  ELSE 'Sin entregar' END      AS "Entrega",
  o.a_tiempo                                   AS "Entregada a tiempo (1/0)",
  CASE
    WHEN o.dias_atraso IS NULL THEN '0. Sin entregar'
    WHEN o.dias_atraso <= -8   THEN '1. 8+ días antes'
    WHEN o.dias_atraso <= 0    THEN '2. 0-7 días antes'
    WHEN o.dias_atraso <= 3    THEN '3. 1-3 días tarde'
    WHEN o.dias_atraso <= 7    THEN '4. 4-7 días tarde'
    WHEN o.dias_atraso <= 14   THEN '5. 8-14 días tarde'
    ELSE                            '6. 15+ días tarde'
  END                                          AS "Rango de atraso",
  o.review_score                               AS "Puntuación reseña",
  CASE WHEN o.review_score IS NULL THEN 'Sin reseña'
       ELSE TO_CHAR(o.review_score) || ' estrellas' END AS "Reseña"
FROM o
JOIN DIM_TIEMPO t       ON t.sk_tiempo       = o.sk_fecha_compra
JOIN DIM_CLIENTE c      ON c.sk_cliente      = o.sk_cliente
JOIN DIM_ESTADO_ORDEN e ON e.sk_estado_orden = o.sk_estado_orden;

-- ---------------------------------------------------------------------
-- V_EXCEL_PAGOS · cómo pagan los clientes
-- Pregunta 7. Medida sumable: Monto pagado.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW V_EXCEL_PAGOS AS
SELECT
  f.order_id                                   AS "Orden",
  f.payment_sequential                         AS "Secuencia pago",
  t.anio                                       AS "Año",
  t.anio_mes                                   AS "Año-Mes",
  c.region                                     AS "Región cliente",
  c.estado                                     AS "Estado cliente",
  tp.tipo_pago_es                              AS "Tipo de pago",
  e.estado_orden_es                            AS "Estado orden",
  f.cuotas                                     AS "Cuotas",
  CASE
    WHEN f.cuotas IS NULL OR f.cuotas = 1 THEN '1. Contado (1 cuota)'
    WHEN f.cuotas <= 3  THEN '2. 2-3 cuotas'
    WHEN f.cuotas <= 6  THEN '3. 4-6 cuotas'
    WHEN f.cuotas <= 10 THEN '4. 7-10 cuotas'
    ELSE                     '5. 11+ cuotas'
  END                                          AS "Rango de cuotas",
  f.monto_pago                                 AS "Monto pagado BRL"
FROM FACT_PAGOS f
JOIN DIM_TIEMPO t        ON t.sk_tiempo       = f.sk_fecha_compra
JOIN DIM_CLIENTE c       ON c.sk_cliente      = f.sk_cliente
JOIN DIM_TIPO_PAGO tp    ON tp.sk_tipo_pago   = f.sk_tipo_pago
JOIN DIM_ESTADO_ORDEN e  ON e.sk_estado_orden = f.sk_estado_orden;

-- ---------------------------------------------------------------------
-- Comprobación: las vistas deben cuadrar con las tablas de hechos
-- (esperado: 112,650 · 98,666 · 103,886 filas y los mismos montos)
-- ---------------------------------------------------------------------
SELECT 'V_EXCEL_VENTAS' vista, COUNT(*) filas, ROUND(SUM("Venta BRL"), 2) monto FROM V_EXCEL_VENTAS
UNION ALL
SELECT 'V_EXCEL_ORDENES', COUNT(*), ROUND(SUM("Venta BRL"), 2) FROM V_EXCEL_ORDENES
UNION ALL
SELECT 'V_EXCEL_PAGOS', COUNT(*), ROUND(SUM("Monto pagado BRL"), 2) FROM V_EXCEL_PAGOS
UNION ALL
SELECT 'FACT_VENTAS', COUNT(*), ROUND(SUM(monto_total), 2) FROM FACT_VENTAS
UNION ALL
SELECT 'FACT_PAGOS', COUNT(*), ROUND(SUM(monto_pago), 2) FROM FACT_PAGOS;
