CREATE TABLE Dim_Clientes (
id_cliente INT PRIMARY KEY,
nombre VARCHAR(100),
ciudad VARCHAR(50),
pais VARCHAR(50)
);

CREATE TABLE Dim_Productos (
id_producto INT PRIMARY KEY,
nombre VARCHAR(100),
categoria VARCHAR(50)
);

CREATE TABLE Dim_Tiempo (
id_fecha INT PRIMARY KEY,
fecha DATE,
año INT,
mes INT,
dia INT
);

CREATE TABLE Hechos_Ventas (
id_venta INT PRIMARY KEY,
id_cliente INT,
id_producto INT,
id_fecha INT,
cantidad INT,
total DECIMAL(10,2),
FOREIGN KEY (id_cliente) REFERENCES Dim_Clientes(id_cliente),
FOREIGN KEY (id_producto) REFERENCES Dim_Productos(id_producto),
FOREIGN KEY (id_fecha) REFERENCES Dim_Tiempo(id_fecha)
);

CREATE EXTENSION dblink;
INSERT INTO Dim_Clientes (id_cliente, nombre, ciudad, pais)
SELECT * FROM dblink('dbname=Ventas user=postgres password=abcd host=localhost',
'SELECT id_cliente, nombre, ciudad, pais FROM Clientes')
AS t(id_cliente INT, nombre VARCHAR, ciudad VARCHAR, pais VARCHAR);

INSERT INTO Dim_Productos (id_producto, nombre, categoria)
SELECT id_producto, nombre, categoria
FROM dblink('dbname=Ventas user=postgres password=abcd host=localhost',
'SELECT id_producto, nombre, categoria FROM Productos')
AS t(id_producto INT, nombre VARCHAR, categoria VARCHAR);

CREATE SEQUENCE dim_tiempo_id_fecha_seq START 1;
INSERT INTO Dim_Tiempo (id_fecha, fecha, año, mes, dia)
SELECT NEXTVAL('dim_tiempo_id_fecha_seq'), -- Genera un nuevo id_fecha automáticamente
fecha_venta,
EXTRACT(YEAR FROM fecha_venta) AS año,
EXTRACT(MONTH FROM fecha_venta) AS mes,
EXTRACT(DAY FROM fecha_venta) AS dia
FROM dblink('dbname=Ventas user=postgres password=abcd host=localhost',
'SELECT fecha_venta FROM Ventas')
AS t(fecha_venta DATE);

INSERT INTO Hechos_Ventas (id_venta, id_cliente, id_producto, id_fecha, cantidad, total)
SELECT
v.id_venta,
v.id_cliente,
v.id_producto,
dt.id_fecha, -- Aquí obtenemos el id_fecha de Dim_Tiempo correspondiente
v.cantidad,
v.total
FROM dblink('dbname=Ventas user=postgres password=abcd host=localhost',
'SELECT id_venta, id_cliente, id_producto, fecha_venta, cantidad, total FROM
Ventas')
AS v(id_venta INT, id_cliente INT, id_producto INT, fecha_venta DATE, cantidad INT, total
DECIMAL)
JOIN Dim_Tiempo dt ON v.fecha_venta = dt.fecha;