-- Creación de tablas
CREATE TABLE Dim_Transportistas (
id_transportista INT PRIMARY KEY,
nombre VARCHAR(100)
);

CREATE TABLE Hechos_Envios (
id_envio INT PRIMARY KEY,
id_venta INT,
id_transportista INT,
id_fecha INT,
estado VARCHAR(50),
FOREIGN KEY (id_venta) REFERENCES Hechos_Ventas(id_venta),
FOREIGN KEY (id_transportista) REFERENCES Dim_Transportistas(id_transportista),
FOREIGN KEY (id_fecha) REFERENCES Dim_Tiempo(id_fecha)
);

CREATE TABLE Hechos_Tiempo_Procesamiento (
    id_tiempo_procesamiento INT PRIMARY KEY,
    id_venta INT,
    id_envio INT,
    id_fecha_venta INT,
    id_fecha_envio INT,
    tiempo_procesamiento INT,
    FOREIGN KEY (id_venta) REFERENCES Hechos_Ventas(id_venta),
    FOREIGN KEY (id_envio) REFERENCES Hechos_Envios(id_envio),
    FOREIGN KEY (id_fecha_venta) REFERENCES Dim_Tiempo(id_fecha),
    FOREIGN KEY (id_fecha_envio) REFERENCES Dim_Tiempo(id_fecha)
);

-- Creación de funciones y triggers necesarios
CREATE OR REPLACE FUNCTION asignar_fechas_y_tiempo_procesamiento()
RETURNS TRIGGER AS $$
DECLARE
    fecha_venta DATE;
    fecha_envio DATE;
BEGIN
    SELECT fecha INTO fecha_venta FROM Dim_Tiempo WHERE id_fecha = (SELECT id_fecha FROM Hechos_Ventas WHERE id_venta = NEW.id_venta);
    SELECT fecha INTO fecha_envio FROM Dim_Tiempo WHERE id_fecha = (SELECT id_fecha FROM Hechos_Envios WHERE id_envio = NEW.id_envio);
    
    NEW.id_fecha_venta := (SELECT id_fecha FROM Hechos_Ventas WHERE id_venta = NEW.id_venta);
    NEW.id_fecha_envio := (SELECT id_fecha FROM Hechos_Envios WHERE id_envio = NEW.id_envio);
    NEW.tiempo_procesamiento := fecha_envio - fecha_venta;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_asignar_fechas_y_tiempo_procesamiento
BEFORE INSERT OR UPDATE ON Hechos_Tiempo_Procesamiento
FOR EACH ROW
EXECUTE FUNCTION asignar_fechas_y_tiempo_procesamiento();

-- Insertar datos en Dim_Transportistas
INSERT INTO Dim_Transportistas (id_transportista, nombre)
SELECT id_transportista, nombre
FROM dblink('dbname=Logistica user=postgres password=abcd host=localhost', 
			'SELECT id_transportista, nombre FROM transportistas')
AS t(id_transportista INT, nombre VARCHAR);

-- Modificación de la secuencia para calcular las entradas de dim_tiempo
DROP SEQUENCE IF EXISTS dim_tiempo_id_fecha_seq;

-- Ajustar la secuencia para que inicie en el siguiente ID disponible
DO $$
DECLARE
    max_id INT;
BEGIN
    SELECT COALESCE(MAX(id_fecha), 0) + 1 INTO max_id FROM Dim_Tiempo;
    EXECUTE format('CREATE SEQUENCE dim_tiempo_id_fecha_seq START WITH %s', max_id);
END $$;

-- Insertar fechas de venta
INSERT INTO Dim_Tiempo (id_fecha, fecha, año, mes, dia)
SELECT NEXTVAL('dim_tiempo_id_fecha_seq'), 
       fecha_venta,
       EXTRACT(YEAR FROM fecha_venta) AS año,
       EXTRACT(MONTH FROM fecha_venta) AS mes,
       EXTRACT(DAY FROM fecha_venta) AS dia
FROM dblink('dbname=Ventas user=postgres password=abcd host=localhost',
            'SELECT DISTINCT fecha_venta FROM Ventas')
AS t(fecha_venta DATE)
WHERE NOT EXISTS (SELECT 1 FROM Dim_Tiempo WHERE Dim_Tiempo.fecha = t.fecha_venta);

-- Insertar fechas de envío
INSERT INTO Dim_Tiempo (id_fecha, fecha, año, mes, dia)
SELECT NEXTVAL('dim_tiempo_id_fecha_seq'), 
       fecha_envio,
       EXTRACT(YEAR FROM fecha_envio) AS año,
       EXTRACT(MONTH FROM fecha_envio) AS mes,
       EXTRACT(DAY FROM fecha_envio) AS dia
FROM dblink('dbname=Logistica user=postgres password=abcd host=localhost',
            'SELECT DISTINCT fecha_envio FROM Envios')
AS t(fecha_envio DATE)
WHERE NOT EXISTS (SELECT 1 FROM Dim_Tiempo WHERE Dim_Tiempo.fecha = t.fecha_envio);

-- Insertar datos en Hechos_Envios
INSERT INTO Hechos_Envios (id_envio, id_venta, id_transportista, id_fecha, estado)
SELECT 
    e.id_envio,         -- id_envio de la tabla Envios en Logistica
    v.id_venta,         -- id_venta de Hechos_Ventas (OLAP)
    t.id_transportista, -- id_transportista de Dim_Transportistas (OLAP)
    dt.id_fecha,        -- id_fecha de Dim_Tiempo (correspondiente a fecha_envio)
    e.estado            -- estado de la tabla Envios en Logistica
FROM dblink('dbname=Logistica user=postgres password=abcd host=localhost', 
            'SELECT id_envio, id_venta, id_transportista, fecha_envio, estado FROM envios')
    AS e(id_envio INT, id_venta INT, id_transportista INT, fecha_envio DATE, estado VARCHAR(50)) 
JOIN Hechos_Ventas v ON v.id_venta = e.id_venta
JOIN Dim_Transportistas t ON e.id_transportista = t.id_transportista
JOIN Dim_Tiempo dt ON e.fecha_envio = dt.fecha;

-- Insertar datos en Hechos_Tiempo_Procesamiento
CREATE SEQUENCE hechos_tiempo_procesamiento_seq START 1;
INSERT INTO Hechos_Tiempo_Procesamiento (id_tiempo_procesamiento, id_venta, id_envio, id_fecha_venta, id_fecha_envio, tiempo_procesamiento)
SELECT 
    NEXTVAL('hechos_tiempo_procesamiento_seq'),
    e.id_venta,
    e.id_envio,
    dv.id_fecha AS id_fecha_venta,
    de.id_fecha AS id_fecha_envio,
    de.fecha - dv.fecha AS tiempo_procesamiento
FROM Hechos_Envios e
JOIN Hechos_Ventas v ON e.id_venta = v.id_venta
JOIN Dim_Tiempo dv ON v.id_fecha = dv.id_fecha
JOIN Dim_Tiempo de ON e.id_fecha = de.id_fecha;