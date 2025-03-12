SELECT 
    c.pais, 
    COUNT(hv.id_venta) AS total_ventas
FROM Hechos_Ventas hv
JOIN Dim_Clientes c ON hv.id_cliente = c.id_cliente
JOIN Dim_Tiempo t ON hv.id_fecha = t.id_fecha
WHERE t.año = (SELECT MAX(año) FROM Dim_Tiempo) -- Último año registrado
GROUP BY c.pais
ORDER BY total_ventas DESC;

WITH Ranked_Products AS (
    SELECT 
        p.categoria, 
        p.nombre AS producto,
        SUM(hv.cantidad) AS total_vendido,
        ROW_NUMBER() OVER (PARTITION BY p.categoria ORDER BY SUM(hv.cantidad) DESC) AS ranking
    FROM Hechos_Ventas hv
    JOIN Dim_Productos p ON hv.id_producto = p.id_producto
    JOIN Dim_Tiempo t ON hv.id_fecha = t.id_fecha
    WHERE t.año >= EXTRACT(YEAR FROM CURRENT_DATE) - 10  -- Última década
    GROUP BY p.categoria, p.nombre
)
SELECT categoria, producto, total_vendido
FROM Ranked_Products
WHERE ranking <= 2
ORDER BY categoria, ranking;

SELECT 
    c.id_cliente, 
    c.nombre AS cliente, 
    SUM(hv.total) AS gasto_total
FROM Hechos_Ventas hv
JOIN Dim_Clientes c ON hv.id_cliente = c.id_cliente
JOIN Dim_Tiempo t ON hv.id_fecha = t.id_fecha
WHERE t.año = EXTRACT(YEAR FROM CURRENT_DATE) - 1  -- Último año
GROUP BY c.id_cliente, c.nombre
ORDER BY gasto_total DESC;

SELECT 
    t.año, 
    t.mes, 
    SUM(hv.cantidad) AS total_unidades_vendidas,
    SUM(hv.total) AS total_ingresos
FROM Hechos_Ventas hv
JOIN Dim_Tiempo t ON hv.id_fecha = t.id_fecha
WHERE t.año >= EXTRACT(YEAR FROM CURRENT_DATE) - 2  -- Últimos dos años
GROUP BY t.año, t.mes
ORDER BY t.año DESC, t.mes ASC;

SELECT 
    dp.categoria, 
    SUM(hv.total) AS total_ingresos
FROM Hechos_Ventas hv
JOIN Dim_Productos dp ON hv.id_producto = dp.id_producto
JOIN Dim_Tiempo dt ON hv.id_fecha = dt.id_fecha
WHERE dt.año = EXTRACT(YEAR FROM CURRENT_DATE) - 1  -- Año pasado
GROUP BY dp.categoria
ORDER BY total_ingresos DESC
LIMIT 1;

SELECT COUNT(DISTINCT hv.id_cliente) AS clientes_primera_compra
FROM Hechos_Ventas hv
JOIN Dim_Tiempo dt ON hv.id_fecha = dt.id_fecha
JOIN (
    SELECT id_cliente, MIN(fecha) AS primera_compra
    FROM Hechos_Ventas hv
    JOIN Dim_Tiempo dt ON hv.id_fecha = dt.id_fecha
    GROUP BY id_cliente
) AS primera_venta ON hv.id_cliente = primera_venta.id_cliente AND dt.fecha = primera_venta.primera_compra
WHERE dt.fecha >= CURRENT_DATE - INTERVAL '6 months';

SELECT 
    t.nombre AS transportista,
    COUNT(e.id_envio) AS cantidad_envios
FROM Hechos_Envios e
JOIN Dim_Transportistas t ON e.id_transportista = t.id_transportista
JOIN Dim_Tiempo dt ON e.id_fecha = dt.id_fecha
WHERE dt.fecha >= CURRENT_DATE - INTERVAL '2 year'
GROUP BY t.id_transportista, t.nombre
ORDER BY cantidad_envios DESC;

SELECT 
    v.id_venta,
    COUNT(e.id_envio) AS cantidad_envios,
    v.total AS total_venta,
    v.id_cliente,
    c.nombre AS cliente
FROM Hechos_Envios e
JOIN Hechos_Ventas v ON e.id_venta = v.id_venta
JOIN Dim_Clientes c ON v.id_cliente = c.id_cliente
JOIN Dim_Tiempo dt ON e.id_fecha = dt.id_fecha
WHERE dt.fecha >= CURRENT_DATE - INTERVAL '1 year'
GROUP BY v.id_venta, v.total, v.id_cliente, c.nombre
HAVING COUNT(e.id_envio) > 1
ORDER BY cantidad_envios DESC;

SELECT 
    t.nombre AS transportista,
    AVG(de.fecha - dv.fecha) AS promedio_dias_diferencia
FROM Hechos_Envios e
JOIN Hechos_Ventas v ON e.id_venta = v.id_venta
JOIN Dim_Transportistas t ON e.id_transportista = t.id_transportista
JOIN Dim_Tiempo dv ON v.id_fecha = dv.id_fecha  -- Fecha de la venta
JOIN Dim_Tiempo de ON e.id_fecha = de.id_fecha  -- Fecha del envío
GROUP BY t.nombre
ORDER BY promedio_dias_diferencia DESC;

SELECT 
    t.nombre AS transportista,
    COUNT(e.id_envio) AS cantidad_envios_entregados
FROM Hechos_Envios e
JOIN Dim_Transportistas t ON e.id_transportista = t.id_transportista
WHERE e.estado = 'Entregado'  -- Cambia 'entregado' por el valor que indique un envío exitoso
AND e.id_fecha IN (
    SELECT id_fecha
    FROM Dim_Tiempo
    WHERE año = EXTRACT(YEAR FROM CURRENT_DATE) - 1  -- Filtra por el último año
)
GROUP BY t.nombre
ORDER BY cantidad_envios_entregados DESC;