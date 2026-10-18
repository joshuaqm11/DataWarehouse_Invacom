-- =====================================================================
-- 04_dblinks.sql
-- Crea los database links entre Staging y Producción y la vista de
-- cuadre. Ejecutar una vez por entorno (re-ejecutable).
--
-- EJECUTAR: SQL Developer · F5 (Ejecutar script), NO Ctrl+Enter.
--           El script cambia de usuario con CONNECT.
--           Leer resultado en la pestaña "Salida de script".
--
-- CONFIGURACIÓN: edite SOLO la sección de DEFINE antes de ejecutar.
--   Para conocer su usuario y servicio de staging, conéctese a
--   ConexionProyecto y ejecute:
--     SELECT USER, SYS_CONTEXT('USERENV','CON_NAME') FROM dual;
-- =====================================================================

-- ---------------------------------------------------------------------
-- CONFIGURACIÓN (cada integrante ajusta estos valores)
-- ---------------------------------------------------------------------
DEFINE usuario_staging = USUARIO_STAGING
DEFINE clave_staging   = CLAVE_STAGING
DEFINE clave_system    = CLAVE_SYSTEM
DEFINE usuario_dw      = DW_INVACOM
DEFINE clave_dw        = Invacom2026
DEFINE servicio        = XEPDB1

-- No subir contraseñas reales al repositorio: dejar como marcadores.
-- ---------------------------------------------------------------------

SET VERIFY   OFF
SET FEEDBACK ON
SET ECHO     OFF
SET SERVEROUTPUT ON
SET LINESIZE 220
SET PAGESIZE 100
SET TRIMSPOOL ON


-- =====================================================================
-- PASO 1 · Permisos necesarios (requiere SYSTEM)
-- =====================================================================

---===== PASO 1: Permisos (SYSTEM) =====
CONNECT system/"&clave_system"@localhost:1521/&servicio

-- Verificar que global_names este en FALSE.
-- Si devuelve TRUE ejecutar: ALTER SYSTEM SET global_names = FALSE;
SELECT name, value
FROM   v$parameter
WHERE  name = 'global_names';

GRANT CREATE DATABASE LINK TO &usuario_dw;
GRANT CREATE DATABASE LINK TO &usuario_staging;
GRANT CREATE VIEW           TO &usuario_dw;


-- =====================================================================
-- PASO 2 · LNK_STAGING  (DW -> Staging)
-- Permite consultar las tablas STG_* desde el esquema de produccion.
-- =====================================================================

---===== PASO 2: LNK_STAGING (usuario DW) =====
CONNECT &usuario_dw/"&clave_dw"@localhost:1521/&servicio

-- Eliminar el link si ya existe (-2024 = link no encontrado, se ignora)
BEGIN
  EXECUTE IMMEDIATE 'DROP DATABASE LINK LNK_STAGING';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -2024 THEN RAISE; END IF;
END;
/

CREATE DATABASE LINK LNK_STAGING
  CONNECT TO &usuario_staging IDENTIFIED BY "&clave_staging"
  USING 'localhost:1521/&servicio';

-- Prueba de vida
-- Esperado: 112650 filas
SELECT COUNT(*) AS items_en_staging
FROM   STG_ORDER_ITEMS@LNK_STAGING;

-- Esperado: usuario de staging
SELECT username AS usuario_remoto
FROM   user_users@LNK_STAGING;

-- Esperado: 9 tablas STG_*
SELECT table_name
FROM   user_tables@LNK_STAGING
WHERE  table_name LIKE 'STG_%'
ORDER  BY table_name;


-- =====================================================================
-- PASO 3 · Vista permanente de cuadre (en el esquema DW)
-- Compara conteos y totales entre staging y produccion.
-- Consultar con: SELECT * FROM V_CUADRE_STAGING_PRODUCCION ORDER BY control;
-- =====================================================================

-- ===== PASO 3: Vista V_CUADRE_STAGING_PRODUCCION =====

CREATE OR REPLACE VIEW V_CUADRE_STAGING_PRODUCCION AS
SELECT control,
       staging,
       produccion,
       staging - produccion                                        AS diferencia,
       CASE WHEN ABS(staging - produccion) < 0.01 THEN 'OK'
            ELSE 'REVISAR'
       END                                                         AS resultado
FROM (
  SELECT 1                    n,
         'Items de venta'     control,
         (SELECT COUNT(*)     FROM STG_ORDER_ITEMS@LNK_STAGING)   staging,
         (SELECT COUNT(*)     FROM FACT_VENTAS)                    produccion
  FROM dual
  UNION ALL
  SELECT 2, 'Pagos',
         (SELECT COUNT(*)     FROM STG_ORDER_PAYMENTS@LNK_STAGING),
         (SELECT COUNT(*)     FROM FACT_PAGOS)
  FROM dual
  UNION ALL
  SELECT 3, 'Clientes reales',
         (SELECT COUNT(DISTINCT customer_unique_id)
          FROM STG_CUSTOMERS@LNK_STAGING),
         (SELECT COUNT(*)     FROM DIM_CLIENTE WHERE sk_cliente > 0)
  FROM dual
  UNION ALL
  SELECT 4, 'Ventas totales (BRL)',
         (SELECT ROUND(SUM(price + freight_value), 2)
          FROM STG_ORDER_ITEMS@LNK_STAGING),
         (SELECT ROUND(SUM(monto_total), 2)    FROM FACT_VENTAS)
  FROM dual
  UNION ALL
  SELECT 5, 'Pagos totales (BRL)',
         (SELECT ROUND(SUM(payment_value), 2)
          FROM STG_ORDER_PAYMENTS@LNK_STAGING),
         (SELECT ROUND(SUM(monto_pago), 2)     FROM FACT_PAGOS)
  FROM dual
);

SELECT * FROM V_CUADRE_STAGING_PRODUCCION ORDER BY control;


-- =====================================================================
-- PASO 4 · LNK_PRODUCCION  (Staging -> DW)
-- Permite consultar las tablas del DW desde el esquema de staging.
-- =====================================================================
PROMPT
PROMPT ===== PASO 4: LNK_PRODUCCION (usuario Staging) =====
CONNECT &usuario_staging/"&clave_staging"@localhost:1521/&servicio

BEGIN
  EXECUTE IMMEDIATE 'DROP DATABASE LINK LNK_PRODUCCION';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -2024 THEN RAISE; END IF;
END;
/

CREATE DATABASE LINK LNK_PRODUCCION
  CONNECT TO &usuario_dw IDENTIFIED BY "&clave_dw"
  USING 'localhost:1521/&servicio';

-- Prueba de vida
-- Esperado: 112650 filas
SELECT COUNT(*) AS ventas_en_dw
FROM   FACT_VENTAS@LNK_PRODUCCION;

-- Esperado: DW_INVACOM
SELECT username AS usuario_remoto
FROM   user_users@LNK_PRODUCCION;

-- Esperado: 6 DIM_*, 2 FACT_*, ETL_LOG_CARGA
SELECT table_name
FROM   user_tables@LNK_PRODUCCION
ORDER  BY table_name;


-- =====================================================================
-- LIMPIEZA OPCIONAL (ejecutar manualmente si se desean eliminar)
-- =====================================================================
-- Como DW_INVACOM:
--   DROP VIEW  V_CUADRE_STAGING_PRODUCCION;
--   DROP DATABASE LINK LNK_STAGING;
-- Como &usuario_staging:
--   DROP DATABASE LINK LNK_PRODUCCION;
-- =====================================================================
