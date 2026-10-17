-- =====================================================================
-- 99_eliminar_dw.sql · Borra TODAS las tablas del DW para recrearlas.
-- EJECUTAR: con la conexión DW_INVACOM. Solo si cambia el modelo.
-- Después: 01_dimensiones.sql -> 02_hechos.sql -> ETL
-- =====================================================================
DROP TABLE FACT_VENTAS      PURGE;
DROP TABLE FACT_PAGOS       PURGE;
DROP TABLE DIM_TIEMPO       PURGE;
DROP TABLE DIM_CLIENTE      PURGE;
DROP TABLE DIM_VENDEDOR     PURGE;
DROP TABLE DIM_PRODUCTO     PURGE;
DROP TABLE DIM_ESTADO_ORDEN PURGE;
DROP TABLE DIM_TIPO_PAGO    PURGE;
