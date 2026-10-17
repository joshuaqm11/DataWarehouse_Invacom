-- =====================================================================
-- 00_crear_usuario_dw.sql
-- Crea el esquema DW_INVACOM que alojará el Data Warehouse.
--
-- EJECUTAR: en SQL Developer con la conexión "Administrador" (SYSTEM),
--           como script (F5). Solo una vez por máquina.
--
-- IMPORTANTE: la conexión de administrador debe apuntar a la PDB
-- (servicio XEPDB1 / FREEPDB1), la misma donde están las tablas STG_*.
-- Si al ejecutar aparece ORA-65096, están conectados al contenedor raíz
-- (CDB): cambien la conexión al servicio de la PDB.
-- =====================================================================

-- Si la conexión Administrador apunta al contenedor raíz (CDB$ROOT),
-- esta línea cambia la sesión a la PDB. Usen el MISMO contenedor donde
-- están las tablas STG_* (ver consulta en ConexionProyecto):
--   SELECT SYS_CONTEXT('USERENV','CON_NAME') FROM dual;
ALTER SESSION SET CONTAINER = XEPDB1;   -- o FREEPDB1 según su instalación

-- Verificación: debe mostrar XEPDB1 / FREEPDB1, NO "CDB$ROOT"
SELECT SYS_CONTEXT('USERENV', 'CON_NAME') AS contenedor FROM dual;

-- Contraseña local: cámbienla si quieren, pero NO la suban distinta al repo;
-- cada quien pone la suya en etl/.env
CREATE USER DW_INVACOM IDENTIFIED BY "Invacom2026"
  DEFAULT TABLESPACE USERS
  QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION   TO DW_INVACOM;
GRANT CREATE TABLE     TO DW_INVACOM;
GRANT CREATE VIEW      TO DW_INVACOM;
GRANT CREATE SEQUENCE  TO DW_INVACOM;
GRANT CREATE PROCEDURE TO DW_INVACOM;

-- Comprobación
SELECT username, default_tablespace, account_status
FROM dba_users
WHERE username = 'DW_INVACOM';
