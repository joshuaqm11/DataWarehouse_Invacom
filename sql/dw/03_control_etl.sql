-- =====================================================================
-- 03_control_etl.sql · Bitácora de ejecuciones del ETL
-- EJECUTAR: con la conexión DW_INVACOM, como script (F5), después de 02.
-- El ETL (etl/main.py) registra aquí cada carga: filas leídas, cargadas,
-- rechazadas, duración y estado. Sirve como evidencia de control.
-- =====================================================================
CREATE TABLE ETL_LOG_CARGA (
  id_log            NUMBER GENERATED ALWAYS AS IDENTITY,
  id_ejecucion      VARCHAR2(20)   NOT NULL,       -- AAAAMMDD_HHMMSS
  fecha_registro    DATE DEFAULT SYSDATE NOT NULL,
  tabla             VARCHAR2(30)   NOT NULL,
  filas_leidas      NUMBER,
  filas_cargadas    NUMBER,
  filas_rechazadas  NUMBER,
  estado            VARCHAR2(10)   NOT NULL,       -- OK / ERROR
  duracion_seg      NUMBER(10,2),
  mensaje           VARCHAR2(4000),
  CONSTRAINT pk_etl_log_carga PRIMARY KEY (id_log)
);

-- Consulta útil: resultado de la última ejecución
-- SELECT * FROM ETL_LOG_CARGA
-- WHERE id_ejecucion = (SELECT MAX(id_ejecucion) FROM ETL_LOG_CARGA)
-- ORDER BY id_log;
