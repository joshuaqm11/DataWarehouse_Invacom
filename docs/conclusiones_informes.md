# Conclusiones de los informes (Excel conectado al DW)

Responsable: Joseph · Libro: `informes/Informes_DW_Invacom.xlsx`

Cada informe responde una pregunta de negocio del modelo dimensional (`docs/modelo_dimensional.md`, sección 6). Las cifras salen de las tablas dinámicas del libro, que leen las vistas `V_EXCEL_*` del esquema `DW_INVACOM`. Montos en reales brasileños (BRL).

**Criterio común de ventas (informes 1 a 4):** se excluyen las órdenes *Cancelada* y *No disponible* para medir solo ventas efectivas. Con ese filtro las ventas suman **15,735,527.03 BRL**; sin filtro, **15,843,553.24 BRL** (el total del KPI del Tablero y del cuadre con staging). La diferencia, 108,026 BRL, corresponde a órdenes canceladas o no disponibles.

---

## Informe 1 · Ventas por mes
**Pregunta:** ¿cómo evolucionan las ventas?

- Las ventas crecen de forma sostenida durante 2017: de **136,943 BRL** en enero a **764,756 BRL** en octubre.
- **Noviembre de 2017** es el mes más alto del periodo (**1,172,192 BRL**), coincidiendo con Black Friday.
- En 2018 las ventas se estabilizan entre **0.98 y 1.16 millones BRL** por mes.
- Se excluyen los meses incompletos de los extremos (2016 y septiembre de 2018), que tienen muy pocas órdenes en la fuente y harían parecer una caída que no existió.

**Conclusión:** el negocio creció fuerte en 2017 y en 2018 se mantiene en un nivel alto y estable; noviembre es la temporada clave.

## Informe 2 · Top 10 categorías y peso del flete
**Pregunta:** ¿qué categorías generan más ingreso y cuánto pesa el flete?

| Categoría | Ventas (BRL) | % de ventas | Flete / precio |
|---|---:|---:|---:|
| health_beauty | 1,437,666 | 9.1% | 14.5% |
| watches_gifts | 1,298,292 | 8.3% | 8.4% |
| bed_bath_table | 1,240,386 | 7.9% | 19.7% |
| sports_leisure | 1,147,245 | 7.3% | 17.1% |
| computers_accessories | 1,050,942 | 6.7% | 16.2% |
| furniture_decor | 899,626 | 5.7% | 23.7% |
| housewares | 772,035 | 4.9% | 23.2% |
| cool_stuff | 704,086 | 4.5% | 13.4% |
| auto | 678,607 | 4.3% | 15.7% |
| garden_tools | 579,525 | 3.7% | 20.5% |

- Las ventas están repartidas: la categoría líder no llega al 10% del total.
- Los productos voluminosos (**muebles y artículos del hogar**) pagan el flete más caro, más del 23% del precio; los **relojes** apenas el 8.4%.
- El % de flete se calcula como flete total ÷ precio total de la categoría (campo calculado), no como promedio de porcentajes.

**Conclusión:** salud y belleza, relojes y cama/baño lideran; en hogar y muebles el flete reduce el margen y es candidato a negociar tarifas logísticas.

## Informe 3 · Ventas por región y estado del cliente
**Pregunta:** ¿dónde se concentran las compras?

| Región | % de las ventas |
|---|---:|
| Sudeste | 64.6% |
| Sur | 14.5% |
| Nordeste | 11.9% |
| Centro-Oeste | 6.4% |
| Norte | 2.6% |

**Conclusión:** el **Sudeste concentra casi dos tercios de las ventas**. Norte y Nordeste suman solo el 14.5%, y son también las regiones con peor servicio de entrega (informe 5): mejorar la logística ahí es una oportunidad de crecimiento.

## Informe 4 · Top 10 vendedores
**Pregunta:** ¿quiénes son los vendedores que más facturan?

- El vendedor con más ventas facturó **249,393 BRL**; el décimo, **160,583 BRL**.
- **9 de los 10 principales están en São Paulo (SP)**; el otro, en Bahía (BA).
- Los 10 primeros suman solo el **12.9%** de las ventas entre **3,053 vendedores** con ventas efectivas: el ingreso no depende de unos pocos vendedores.
- Los códigos `V-xxxxxxxx` son identificadores abreviados: Olist anonimizó a los vendedores y la fuente no trae nombres.

**Conclusión:** la base de vendedores está muy distribuida y su núcleo está en São Paulo, cerca del mercado principal (Sudeste).

## Informe 5 · Tiempos de entrega por región
**Pregunta:** ¿cuánto tarda la entrega y qué % llega a tiempo en cada región?

| Región | Días promedio | % a tiempo |
|---|---:|---:|
| Norte | 22.1 | 91.4% |
| Nordeste | 19.5 | 87.3% |
| Centro-Oeste | 14.6 | 93.5% |
| Sur | 13.6 | 94.1% |
| Sudeste | 10.3 | 93.9% |
| **Total** | **12.1** | **93.2%** |

- Se usa la vista de **órdenes** (una fila por orden), no la de ventas: si no, una orden con 5 productos pesaría 5 veces en el promedio.
- Los días se **promedian**; el % a tiempo es el promedio de un indicador 1/0. Se excluyen las 2,190 órdenes sin entregar.

**Conclusión:** Norte y Nordeste tardan **casi el doble** que el Sudeste, y el Nordeste tiene el menor cumplimiento (87.3%).

## Informe 6 · Atraso y satisfacción del cliente
**Pregunta:** ¿el atraso baja la satisfacción?

| Rango de atraso | Puntuación promedio (1-5) | Reseñas de 1 estrella |
|---|---:|---:|
| 8+ días antes de lo estimado | 4.32 | 6.5% |
| 0-7 días antes | 4.19 | 7.2% |
| 1-3 días tarde | 3.29 | 25.1% |
| 4-7 días tarde | 2.10 | 58.6% |
| 8-14 días tarde | 1.67 | 70.6% |
| 15+ días tarde | 1.72 | 69.0% |

- Se excluyen las órdenes sin entregar y sin reseña (95,830 órdenes analizadas).

**Conclusión:** el atraso es el factor que más castiga la satisfacción. Con **4 o más días de atraso** la calificación cae a 2 o menos y **más de la mitad** de las reseñas son de 1 estrella.

## Informe 7 · Métodos de pago y cuotas
**Pregunta:** ¿cómo pagan los clientes y en cuántas cuotas?

| Tipo de pago | % del monto pagado |
|---|---:|
| Tarjeta de crédito | 78.3% |
| Boleto bancario | 17.9% |
| Vale / cupón | 2.4% |
| Tarjeta de débito | 1.4% |

| Cuotas (solo tarjeta de crédito) | Pagos | Pago promedio (BRL) |
|---|---:|---:|
| Contado (1 cuota) | 25,457 | 95.87 |
| 2-3 cuotas | 22,874 | 134.23 |
| 4-6 cuotas | 16,257 | 181.32 |
| 7-10 cuotas | 11,866 | 333.83 |
| 11+ cuotas | 341 | 358.34 |

**Conclusión:** la tarjeta de crédito concentra casi 4 de cada 5 reales pagados. La mayoría paga en 1 a 3 cuotas, pero las compras en 7 o más cuotas **triplican** el monto promedio: ofrecer cuotas sin interés impulsa las compras grandes.

---

## Tablero
Reúne en una hoja los 6 indicadores principales y los gráficos de los informes, con filtros de un clic por año y región:

| Indicador | Valor (sin filtros) |
|---|---:|
| Ventas totales | 15,843,553 BRL |
| Unidades vendidas | 112,650 |
| Órdenes | 98,666 |
| Días promedio de entrega | 12.1 |
| % entregas a tiempo | 93.2% |
| Puntuación promedio | 4.10 / 5 |

## Conclusión general
Invacom vende principalmente en el **Sudeste**, mediante **tarjeta de crédito en cuotas**, con un crecimiento fuerte en 2017 y estable en 2018. El principal riesgo para la satisfacción es la **logística en Norte y Nordeste**: las entregas allí son más lentas y el atraso es lo que más baja las calificaciones. Mejorar esos tiempos protegería la reputación y abriría crecimiento en las regiones con menor participación.
