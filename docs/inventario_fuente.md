# Inventario de la base fuente (esquema staging)

Responsable: Fernanda · Consultas: `sql/exploracion/01_inventario_fuente.sql`

Conteo de filas y tipos de columna de las 9 tablas `STG_*` de la fuente Olist. Las relaciones entre tablas están en `docs/fuente_relaciones.md`.

Consulta usada para los tipos:

```sql
SELECT table_name, column_name, data_type, data_length, nullable
FROM user_tab_columns
WHERE table_name LIKE 'STG\_%' ESCAPE '\'
ORDER BY table_name, column_id;
```

## Resumen

| Tabla | Filas | Columnas |
|---|---:|---:|
| STG_ORDERS | 99,441 | 8 |
| STG_ORDER_ITEMS | 112,650 | 7 |
| STG_ORDER_PAYMENTS | 103,886 | 5 |
| STG_ORDER_REVIEWS | 99,224 | 7 |
| STG_CUSTOMERS | 99,441 | 5 |
| STG_SELLERS | 3,095 | 4 |
| STG_PRODUCTS | 32,951 | 9 |
| STG_PRODUCT_CATEGORY_TRANSLATION | 71 | 2 |
| STG_GEOLOCATION | 1,000,163 | 5 |
| **Total** | **1,550,922** | **52** |

## Columnas por tabla

Todas las columnas aceptan nulos (`NULLABLE = Y`). `VARCHAR2` tiene longitud 4000 y `NUMBER` no tiene precisión definida.

### STG_ORDERS
| Columna | Tipo |
|---|---|
| ORDER_ID | VARCHAR2 |
| CUSTOMER_ID | VARCHAR2 |
| ORDER_STATUS | VARCHAR2 |
| ORDER_PURCHASE_TIMESTAMP | VARCHAR2 (fecha como texto) |
| ORDER_APPROVED_AT | VARCHAR2 (fecha como texto) |
| ORDER_DELIVERED_CARRIER_DATE | VARCHAR2 (fecha como texto) |
| ORDER_DELIVERED_CUSTOMER_DATE | VARCHAR2 (fecha como texto) |
| ORDER_ESTIMATED_DELIVERY_DATE | VARCHAR2 (fecha como texto) |

### STG_ORDER_ITEMS
| Columna | Tipo |
|---|---|
| ORDER_ID | VARCHAR2 |
| ORDER_ITEM_ID | VARCHAR2 (número de secuencia guardado como texto) |
| PRODUCT_ID | VARCHAR2 |
| SELLER_ID | VARCHAR2 |
| SHIPPING_LIMIT_DATE | VARCHAR2 (fecha como texto) |
| PRICE | NUMBER |
| FREIGHT_VALUE | NUMBER |

### STG_ORDER_PAYMENTS
| Columna | Tipo |
|---|---|
| ORDER_ID | VARCHAR2 |
| PAYMENT_SEQUENTIAL | NUMBER |
| PAYMENT_TYPE | VARCHAR2 |
| PAYMENT_INSTALLMENTS | NUMBER |
| PAYMENT_VALUE | NUMBER |

### STG_ORDER_REVIEWS
| Columna | Tipo |
|---|---|
| REVIEW_ID | VARCHAR2 |
| ORDER_ID | VARCHAR2 |
| REVIEW_SCORE | NUMBER |
| REVIEW_COMMENT_TITLE | VARCHAR2 |
| REVIEW_COMMENT_MESSAGE | VARCHAR2 |
| REVIEW_CREATION_DATE | VARCHAR2 (fecha como texto) |
| REVIEW_ANSWER_TIMESTAMP | VARCHAR2 (fecha como texto) |

### STG_CUSTOMERS
| Columna | Tipo |
|---|---|
| CUSTOMER_ID | VARCHAR2 |
| CUSTOMER_UNIQUE_ID | VARCHAR2 |
| CUSTOMER_ZIP_CODE_PREFIX | VARCHAR2 |
| CUSTOMER_CITY | VARCHAR2 |
| CUSTOMER_STATE | VARCHAR2 |

### STG_SELLERS
| Columna | Tipo |
|---|---|
| SELLER_ID | VARCHAR2 |
| SELLER_ZIP_CODE_PREFIX | VARCHAR2 |
| SELLER_CITY | VARCHAR2 |
| SELLER_STATE | VARCHAR2 |

### STG_PRODUCTS
| Columna | Tipo |
|---|---|
| PRODUCT_ID | VARCHAR2 |
| PRODUCT_CATEGORY_NAME | VARCHAR2 |
| PRODUCT_NAME_LENGHT | NUMBER |
| PRODUCT_DESCRIPTION_LENGHT | NUMBER |
| PRODUCT_PHOTOS_QTY | NUMBER |
| PRODUCT_WEIGHT_G | NUMBER |
| PRODUCT_LENGTH_CM | NUMBER |
| PRODUCT_HEIGHT_CM | NUMBER |
| PRODUCT_WIDTH_CM | NUMBER |

### STG_PRODUCT_CATEGORY_TRANSLATION
| Columna | Tipo |
|---|---|
| PRODUCT_CATEGORY_NAME | VARCHAR2 |
| PRODUCT_CATEGORY_NAME_ENGLISH | VARCHAR2 |

### STG_GEOLOCATION
| Columna | Tipo |
|---|---|
| GEOLOCATION_ZIP_CODE_PREFIX | VARCHAR2 |
| GEOLOCATION_LAT | NUMBER |
| GEOLOCATION_LNG | NUMBER |
| GEOLOCATION_CITY | VARCHAR2 |
| GEOLOCATION_STATE | VARCHAR2 |

## Observaciones

- **Fechas como texto:** en este esquema todas las fechas son `VARCHAR2`; en otras máquinas del equipo se importaron como `DATE`. El ETL convierte ambos formatos.
- **Sin restricciones declaradas:** ninguna tabla tiene PK ni FK, y todas las columnas aceptan nulos. Por eso la unicidad y la integridad referencial se comprobaron con consultas (`02_perfilado_calidad.sql`, controles 1.1 y 3).
- **Códigos postales como texto:** conserva los ceros a la izquierda; el ETL igual los normaliza a 5 dígitos (R02).
- **`ORDER_ITEM_ID` como texto:** es un número de secuencia dentro de la orden; el ETL lo convierte a número.
- **Nombres del dataset original:** `PRODUCT_NAME_LENGHT` y `PRODUCT_DESCRIPTION_LENGHT` vienen escritas así desde Olist; no se renombran en staging.