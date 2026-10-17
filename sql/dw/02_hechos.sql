-- =====================================================================
-- 02_hechos.sql · Crea las tablas de hechos del DW
-- EJECUTAR: con la conexión DW_INVACOM, como script (F5),
--           DESPUÉS de 01_dimensiones.sql
-- =====================================================================

-- ---------------------------------------------------------------------
-- FACT_VENTAS · Granularidad: una fila = un ítem de una orden
-- ---------------------------------------------------------------------
CREATE TABLE FACT_VENTAS (
  order_id            VARCHAR2(32)  NOT NULL,   -- dimensión degenerada
  order_item_id       NUMBER(3)     NOT NULL,
  sk_fecha_compra     NUMBER(8)     NOT NULL,
  sk_fecha_entrega    NUMBER(8)     NOT NULL,   -- -1 si no se entregó
  sk_cliente          NUMBER        NOT NULL,
  sk_producto         NUMBER        NOT NULL,
  sk_vendedor         NUMBER        NOT NULL,
  sk_estado_orden     NUMBER        NOT NULL,
  cantidad            NUMBER(1)     DEFAULT 1 NOT NULL,
  precio              NUMBER(10,2)  NOT NULL,
  flete               NUMBER(10,2)  NOT NULL,
  monto_total         NUMBER(10,2)  NOT NULL,
  dias_entrega        NUMBER(5),                -- NULL si no se entregó
  dias_atraso         NUMBER(5),                -- negativo = llegó antes
  entregado_a_tiempo  NUMBER(1),                -- 1 / 0 / NULL
  review_score        NUMBER(1),                -- 1..5, NULL sin reseña
  CONSTRAINT pk_fact_ventas PRIMARY KEY (order_id, order_item_id),
  CONSTRAINT fk_fv_fecha_compra  FOREIGN KEY (sk_fecha_compra)  REFERENCES DIM_TIEMPO (sk_tiempo),
  CONSTRAINT fk_fv_fecha_entrega FOREIGN KEY (sk_fecha_entrega) REFERENCES DIM_TIEMPO (sk_tiempo),
  CONSTRAINT fk_fv_cliente   FOREIGN KEY (sk_cliente)      REFERENCES DIM_CLIENTE (sk_cliente),
  CONSTRAINT fk_fv_producto  FOREIGN KEY (sk_producto)     REFERENCES DIM_PRODUCTO (sk_producto),
  CONSTRAINT fk_fv_vendedor  FOREIGN KEY (sk_vendedor)     REFERENCES DIM_VENDEDOR (sk_vendedor),
  CONSTRAINT fk_fv_estado    FOREIGN KEY (sk_estado_orden) REFERENCES DIM_ESTADO_ORDEN (sk_estado_orden),
  CONSTRAINT ck_fv_precio  CHECK (precio >= 0),
  CONSTRAINT ck_fv_flete   CHECK (flete >= 0),
  CONSTRAINT ck_fv_a_tiempo CHECK (entregado_a_tiempo IN (0, 1)),
  CONSTRAINT ck_fv_review  CHECK (review_score BETWEEN 1 AND 5)
);

CREATE INDEX ix_fv_fecha_compra ON FACT_VENTAS (sk_fecha_compra);
CREATE INDEX ix_fv_cliente      ON FACT_VENTAS (sk_cliente);
CREATE INDEX ix_fv_producto     ON FACT_VENTAS (sk_producto);
CREATE INDEX ix_fv_vendedor     ON FACT_VENTAS (sk_vendedor);

-- ---------------------------------------------------------------------
-- FACT_PAGOS · Granularidad: una fila = un pago de una orden
-- ---------------------------------------------------------------------
CREATE TABLE FACT_PAGOS (
  order_id            VARCHAR2(32)  NOT NULL,   -- dimensión degenerada
  payment_sequential  NUMBER(3)     NOT NULL,
  sk_fecha_compra     NUMBER(8)     NOT NULL,
  sk_cliente          NUMBER        NOT NULL,
  sk_tipo_pago        NUMBER        NOT NULL,
  sk_estado_orden     NUMBER        NOT NULL,
  cuotas              NUMBER(3),
  monto_pago          NUMBER(10,2)  NOT NULL,
  CONSTRAINT pk_fact_pagos PRIMARY KEY (order_id, payment_sequential),
  CONSTRAINT fk_fp_fecha_compra FOREIGN KEY (sk_fecha_compra) REFERENCES DIM_TIEMPO (sk_tiempo),
  CONSTRAINT fk_fp_cliente   FOREIGN KEY (sk_cliente)      REFERENCES DIM_CLIENTE (sk_cliente),
  CONSTRAINT fk_fp_tipo_pago FOREIGN KEY (sk_tipo_pago)    REFERENCES DIM_TIPO_PAGO (sk_tipo_pago),
  CONSTRAINT fk_fp_estado    FOREIGN KEY (sk_estado_orden) REFERENCES DIM_ESTADO_ORDEN (sk_estado_orden),
  CONSTRAINT ck_fp_monto CHECK (monto_pago >= 0)
);

CREATE INDEX ix_fp_fecha_compra ON FACT_PAGOS (sk_fecha_compra);
CREATE INDEX ix_fp_cliente      ON FACT_PAGOS (sk_cliente);

-- Comprobación: lista las tablas y restricciones activas del DW
SELECT table_name, constraint_name, constraint_type, status
FROM user_constraints
WHERE constraint_type IN ('P', 'R', 'U')
ORDER BY table_name, constraint_type;
