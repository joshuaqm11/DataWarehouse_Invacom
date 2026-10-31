# Requisitos, objetivos y preguntas de negocio

Responsable: Fernanda · Tareas 1, 2 y 3 del enunciado (requisitos del negocio, necesidades del usuario y objetivos del DW)

## 1. Enunciado del problema

Invacom Inc. S.A. registra su operación de comercio electrónico (fuente Olist, Brasil, 2016-2018) en **9 tablas operativas** separadas: órdenes, ítems, pagos, reseñas, clientes, vendedores, productos, traducción de categorías y geolocalización. Esa estructura sirve para operar, pero no para analizar:

- Para responder una pregunta simple, como las ventas por región, hay que unir varias tablas y conocer reglas que no están documentadas en la base.
- Las tablas no tienen claves primarias ni foráneas declaradas, y presentan problemas de calidad: un cliente real aparece con varios identificadores, códigos postales repetidos más de un millón de veces, ciudades escritas de distintas formas, productos sin categoría y fechas guardadas como texto (ver `docs/calidad_datos.md`).
- No existe un calendario ni indicadores calculados (días de entrega, entrega a tiempo, región del cliente).

En consecuencia, la gerencia y las áreas del negocio no tienen una forma confiable y rápida de conocer cómo evolucionan las ventas, dónde se concentran ni qué afecta la satisfacción del cliente.

## 2. Objetivo general

Implementar un Data Warehouse con modelo dimensional, alimentado mediante un proceso ETL en Python (SQLAlchemy y Pandas) desde la base operativa de Invacom, que integre y limpie los datos de ventas, pagos, entregas y reseñas para responder las preguntas de negocio de la empresa desde tablas dinámicas en Excel.

## 3. Objetivos específicos (medibles)

| # | Objetivo | Meta | Evidencia |
|---|---|---|---|
| OE1 | Cargar completamente los hechos de la fuente | 100% de las filas: 112,650 ítems y 103,886 pagos, 0 rechazadas | Bitácora del ETL y `etl/validar.py` |
| OE2 | Garantizar la exactitud de los montos | Cuadre al centavo con la fuente: 15,843,553.24 BRL en ventas y 16,008,872.12 BRL en pagos | `etl/validar.py`, `docs/evidencias/` |
| OE3 | Asegurar una carga reproducible | Reejecutar el ETL sin duplicar filas; carga completa en menos de 1 minuto | Evidencias de ejecución y reejecución |
| OE4 | Tratar los problemas de calidad con reglas documentadas | Cada problema del perfilado tiene una regla R01–R18 | `docs/calidad_datos.md`, `docs/reglas_etl.md` |
| OE5 | Responder las preguntas de negocio desde Excel | 7 preguntas respondidas con tablas dinámicas conectadas al DW | `informes/Informes_DW_Invacom.xlsx` |

## 4. Usuarios y necesidades

| Usuario | Necesidad | Informe |
|---|---|---|
| Gerencia | Visión general del negocio y su evolución | Tablero e informe 1 |
| Área comercial | Saber qué se vende, dónde y quién vende más | Informes 2, 3 y 4 |
| Logística | Medir tiempos de entrega y cumplimiento por región | Informe 5 |
| Servicio al cliente | Entender qué afecta la satisfacción | Informe 6 |
| Finanzas | Conocer los medios de pago y el uso de cuotas | Informe 7 |

## 5. Preguntas de negocio que responde el DW

| # | Pregunta | Dimensiones | Medidas | Tabla de hechos |
|---|---|---|---|---|
| 1 | ¿Cómo evolucionan las ventas en el tiempo? | Tiempo (año, mes) | Ventas (precio) | FACT_VENTAS |
| 2 | ¿Qué categorías generan más ingreso y cuánto pesa el flete? | Producto (categoría) | Ventas, flete, flete ÷ precio | FACT_VENTAS |
| 3 | ¿Dónde se concentran las compras? | Cliente (región, estado) | Ventas, % del total | FACT_VENTAS |
| 4 | ¿Qué vendedores facturan más? | Vendedor (código, estado) | Ventas | FACT_VENTAS |
| 5 | ¿Cuánto tarda la entrega y qué % llega a tiempo en cada región? | Cliente (región), Tiempo | Días de entrega (promedio), % a tiempo | FACT_VENTAS (vista por orden) |
| 6 | ¿El atraso en la entrega baja la satisfacción? | Rango de atraso | Puntuación promedio, % de reseñas de 1 estrella | FACT_VENTAS (vista por orden) |
| 7 | ¿Cómo pagan los clientes y en cuántas cuotas? | Tipo de pago, rango de cuotas | Monto pagado, cantidad de pagos, pago promedio | FACT_PAGOS |

Las respuestas y conclusiones de cada pregunta están en `docs/conclusiones_informes.md`.

## 6. Alcance

- **Incluye:** ventas, pagos, entregas y puntuación de reseñas de 2016 a 2018.
- **No incluye:** el texto libre de las reseñas, nombres de vendedores o clientes (la fuente está anonimizada) ni costos o márgenes (la fuente no los trae).