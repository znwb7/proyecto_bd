--Bloque 1 (Cálculos, Fechas, Texto y CASE básicos): Consultas 1, 3, 5, 8, 12.  [LISTO] [Por revisar]
--Bloque 2 (Subconsultas, Agregaciones dobles y Anti-Joins): Consultas 2, 6, 7, 9, 10, 11, 14, 17, 19. [LISTO] [Por revisar]
--Bloque 3 (Casos de negocio específicos y Retención): Consultas 4, 15, 16.   [LISTO] [Por revisar]
--Bloque 4 (División Relacional y CTEs Recursivas): Consultas 13, 18, 20. [LISTO] [Por revisar]

--Consulta 1
SELECT E.Nombre AS Estudio, E.Pais_Origen, COUNT(df.ID_Factura) AS Juegos_Vendidos, 
SUM(df.Precio_Venta_Historico * (1.0 - (df.Descuento_Aplicado_Pct / 100.0))) AS Ingreso_Total, 
dbo.fn_clasificar_ingreso(SUM(df.Precio_Venta_Historico * (1.0 - (df.Descuento_Aplicado_Pct / 100.0)))) 
AS Clasificacion
FROM Factura F
JOIN Detalle_Factura DF ON F.ID_Factura = DF.ID_Factura
JOIN Juego_Base JB ON DF.ID_Producto = JB.ID_Producto
JOIN Empresa_Corporativa E ON JB.ID_Estudio_Dev = E.ID_Empresa
WHERE F.Fecha_Hora_Emision >= DATEADD(MONTH, -1, GETDATE())
GROUP BY E.ID_Empresa, E.Nombre, E.Pais_Origen
ORDER BY Ingreso_Total DESC;

--Consulta 2
-- Preguntar al profe si esta permitido el uso de N'algo'
WITH DatosProductos AS (
    SELECT C.ID_Categoria, C.Nombre_Categoria, P.Titulo,
    COALESCE(EB.Nombre, ED.Nombre, N'Desconocido') AS Estudio,
    (ISNULL(V.Unidades_Vendidas, 0) * 2.0) + (ISNULL(R.Total_Resenas, 0) * 1.5) + 
    ISNULL(P.Metacritic_Score, 0.0) AS Puntaje_Popularidad
    FROM Producto_Digital P
    JOIN Juego_Categoria JC ON P.ID_Producto = JC.ID_Producto
    JOIN Categoria_Oficial C ON JC.ID_Categoria = C.ID_Categoria
    LEFT JOIN Juego_Base BG ON P.ID_Producto = BG.ID_Producto
    LEFT JOIN Empresa_Corporativa EB ON BG.ID_Estudio_Dev = EB.ID_Empresa
    LEFT JOIN DLC D ON P.ID_Producto = D.ID_Producto
    LEFT JOIN Juego_Base JBPADRE ON D.ID_Juego_Base = JBPADRE.ID_Producto
    LEFT JOIN Empresa_Corporativa EDLC ON JBPADRE.ID_Estudio_Dev = EDLC.ID_Empresa
    LEFT JOIN (
        SELECT ID_Producto, COUNT(*) AS Unidades_Vendidas
        FROM Detalle_Factura 
        GROUP BY ID_Producto
    ) V ON P.ID_Producto = V.ID_Producto
    LEFT JOIN (
        SELECT ID_Producto, COUNT(*) AS Total_Resenas
        FROM Resena 
        GROUP BY ID_Producto
    ) R ON P.ID_Producto = R.ID_Producto
)

SELECT DP.Nombre_Categoria, DP.Titulo, DP.Estudio, DP.Puntaje_Popularidad
FROM DatosProductos DP
-- Nos quedamos únicamente con el que no tenga ningún "rival" en su misma categoría con mayor puntaje
WHERE NOT EXISTS (
    SELECT 1 
    FROM DatosProductos Rival 
    WHERE Rival.ID_Categoria = DP.ID_Categoria AND Rival.Puntaje_Popularidad > DP.Puntaje_Popularidad
)
ORDER BY Puntaje_Popularidad DESC;

--Consulta 3
-- Extrae todo lo que está después del símbolo '@' en la columna Correo
-- Preguntar al profesor si se puede usar la funcion CHARINDEX (si no se puede bueno, F)
SELECT SUBSTRING(Correo, CHARINDEX('@', Correo) + 1, LEN(Correo)) AS Dominio,
COUNT(*) AS Cantidad_Usuarios
FROM Usuario
GROUP BY SUBSTRING(Correo, CHARINDEX('@', Correo) + 1, LEN(Correo))
HAVING COUNT(*) > 10
ORDER BY Cantidad_Usuarios DESC;

--Consulta 4
WITH PrimeraCompra AS (
    -- Paso 1 y 2: Ordenar y obtener la primera compra (la fecha mínima)
    SELECT ID_Usuario, MIN(Fecha_Hora_Emision) AS Fecha_Primera_Compra
    FROM Factura
    GROUP BY ID_Usuario
),
SegundaCompra AS (
    -- Paso 3: Obtener la segunda compra (la fecha mínima que es estrictamente mayor a la primera)
    SELECT F.ID_Usuario, MIN(f.Fecha_Hora_Emision) AS Fecha_Segunda_Compra
    FROM Factura F
    JOIN PrimeraCompra PC ON F.ID_Usuario = PC.ID_Usuario
    WHERE F.Fecha_Hora_Emision > PC.Fecha_Primera_Compra
    GROUP BY F.ID_Usuario
)

-- Paso 4, 5 y 6: Calcular días, filtrar <= 30 y mostrar
SELECT U.Nickname, CAST(PC.Fecha_Primera_Compra AS DATE) AS Fecha_Primera_Compra,
    CAST(SC.Fecha_Segunda_Compra AS DATE) AS Fecha_Segunda_Compra,
    DATEDIFF(DAY, PC.Fecha_Primera_Compra, SC.Fecha_Segunda_Compra) AS Dias_Entre_Compras
FROM PrimeraCompra PC
JOIN SegundaCompra SC ON PC.ID_Usuario = SC.ID_Usuario
JOIN Usuario U ON PC.ID_Usuario = U.ID_Usuario
WHERE DATEDIFF(DAY, PC.Fecha_Primera_Compra, SC.Fecha_Segunda_Compra) <= 30
ORDER BY Dias_Entre_Compras ASC;

--Consulta 5
WITH PesoEstudio AS (
    SELECT E.Nombre AS Estudio, COUNT(JB.ID_Producto) AS Cantidad_Juegos,
    SUM(CAST(JB.Tamano_GB AS DECIMAL(12,2))) AS Total_GB
    FROM Empresa_Corporativa E
    JOIN Juego_Base JB ON E.ID_Empresa = JB.ID_Estudio_Dev
    GROUP BY E.ID_Empresa, E.Nombre
)

--Preguntar al profe si se permite usar VARCHAR o CHAR para concatenar GB o TB

SELECT Estudio,Cantidad_Juegos,
    CASE 
        -- Si el peso total supera o iguala los 1024 GB, lo convertimos y mostramos en TB
        WHEN Total_GB >= 1024.0 THEN CAST(CAST(Total_GB / 1024.0 AS DECIMAL(10,2)) AS VARCHAR(20)) + ' TB'
        -- De lo contrario, se mantiene expresado en GB
        ELSE CAST(CAST(Total_GB AS DECIMAL(10,2)) AS VARCHAR(20)) + ' GB'
    END AS Peso_Total
FROM PesoEstudio
ORDER BY Total_GB DESC;

--Consulta 6
WITH BrutoPorPais AS (
    -- Paso 1: Calcular ingresos brutos por país del comprador
    SELECT U.Pais_Residencia AS Pais, ISNULL(SUM(F.Total_Pagado), 0.0) AS Bruto_Facturas
    FROM Usuario U
    LEFT JOIN Factura F ON U.ID_Usuario = F.ID_Usuario
    GROUP BY U.Pais_Residencia
),
ReembolsosPorPais AS (
    -- Paso 2: Calcular el total de reembolsos por país
    SELECT U.Pais_Residencia AS Pais, ISNULL(SUM(R.Monto_Reembolsado), 0.0) AS Total_Reembolsos
    FROM Usuario U
    JOIN Factura F ON U.ID_Usuario = F.ID_Usuario
    JOIN Reembolso R ON F.ID_Factura = R.ID_Factura
    GROUP BY U.Pais_Residencia
),
NetoPorPais AS (
    -- Paso 3 y 4: Obtener el Total Neto restando los reembolsos
    SELECT BPP.Pais, (BPP.Bruto_Facturas - ISNULL(RPP.Total_Reembolsos, 0.0)) AS Total_Neto
    FROM BrutoPorPais BPP
    LEFT JOIN ReembolsosPorPais RPP ON BPP.Pais = RPP.Pais
),
TotalGlobal AS (
    -- Paso 5: Calcular la suma de todo el neto global para el cálculo del Share
    SELECT SUM(Total_Neto) AS Global_Neto
    FROM NetoPorPais
)

-- Paso 6, 7 y 8: Cálculo del porcentaje y formateo final con VARCHAR y '%'
SELECT N.Pais, CAST(N.Total_Neto AS DECIMAL(12,2)) AS Total_Neto,
    CAST(CAST(
            CASE 
                WHEN G.Global_Neto = 0 THEN 0.00
                ELSE (N.Total_Neto * 100.0) / G.Global_Neto 
            END AS DECIMAL(5,2)
        ) AS VARCHAR(20)
    ) + '%' AS Share
FROM NetoPorPais N
CROSS JOIN TotalGlobal G
ORDER BY Total_Neto DESC;

--Consulta 7
--Preguntar al profe si se puede usar N'algo' ya que sirve para soportar tildes, eñes 
--y caracteres especiales (hace que lo detecte como una cadena Unicode)
WITH UsuariosEstrategia AS (
    -- Paso 1: Usuarios que tienen juegos de la categoría 'Estrategia' en su biblioteca
    SELECT DISTINCT B.ID_Usuario
    FROM Biblioteca B
    JOIN Juego_Categoria JC ON b.ID_Producto = JC.ID_Producto
    JOIN Categoria_Oficial CO ON JC.ID_Categoria = CO.ID_Categoria
    WHERE CO.Nombre_Categoria = N'Estrategia'
),
UsuariosTerror AS (
    -- Paso 2: Usuarios que tienen juegos de la categoría 'Terror' en su biblioteca
    SELECT DISTINCT B.ID_Usuario
    FROM Biblioteca B
    JOIN Juego_Categoria JC ON B.ID_Producto = JC.ID_Producto
    JOIN Categoria_Oficial CO ON JC.ID_Categoria = CO.ID_Categoria
    WHERE CO.Nombre_Categoria = N'Terror'
),
UsuariosConAmbas AS (
    -- Paso 3: Intersección de ambos conjuntos (usuarios que cumplen con ambas categorías)
    SELECT ID_Usuario 
    FROM UsuariosEstrategia
    INTERSECT
    SELECT ID_Usuario 
    FROM UsuariosTerror
),
GastoTotalUsuarios AS (
    -- Paso 4: Calcular el gasto histórico total por usuario basado en sus facturas
    SELECT ID_Usuario, SUM(Total_Pagado) AS Gasto_Total
    FROM Factura
    GROUP BY ID_Usuario
)

-- Paso 5 y 6: Cruzar los usuarios de la intersección con su gasto, filtrar > 100 y mostrar
SELECT U.Nickname, CAST(G.Gasto_Total AS DECIMAL(12,2)) AS Gasto_Total_Historico
FROM UsuariosConAmbas UA
JOIN Usuario U ON UA.ID_Usuario = U.ID_Usuario
JOIN GastoTotalUsuarios G ON UA.ID_Usuario = G.ID_Usuario
WHERE G.Gasto_Total > 100.00
ORDER BY Gasto_Total_Historico DESC;

--Consulta 8
WITH UsuariosClasificados AS (
    SELECT U.ID_Usuario, U.Estado_Cuenta,
        -- Extraemos el año de nacimiento de la fecha
    YEAR(U.Fecha_Nacimiento) AS Anio_Nacimiento,
        -- Clasificamos con CASE según los rangos indicados
    CASE 
        WHEN YEAR(U.Fecha_Nacimiento) > 2000 THEN 'Gen Z'
        WHEN YEAR(U.Fecha_Nacimiento) BETWEEN 1981 AND 2000 THEN 'Millennials'
        ELSE 'Gen X y anteriores'
    END AS Generacion,
        ISNULL(f.Gasto_Total_Usuario, 0.0) AS Gasto_Usuario
    FROM Usuario U
    LEFT JOIN (
        SELECT ID_Usuario, SUM(Total_Pagado) AS Gasto_Total_Usuario
        FROM Factura
        GROUP BY ID_Usuario
    ) F ON U.ID_Usuario = F.ID_Usuario
    WHERE U.Estado = 'Activa'
)

SELECT Generacion, COUNT(ID_Usuario) AS Cantidad_Usuarios_Activos,
AVG(CAST(Gasto_Usuario AS DECIMAL(12,2))) AS Gasto_Promedio
FROM UsuariosClasificados
GROUP BY Generacion
ORDER BY Gasto_Promedio DESC;

--Consulta 9
WITH MetricasJuego AS (
    -- Pasos 1, 2 y 3: Filtrar juegos base, contar reseñas y calcular promedio por juego
    SELECT P.Titulo, COUNT(R.ID_Resena) AS Total_Resenas,
    AVG(CAST(R.Calificacion_1_10 AS DECIMAL(10,4))) AS Promedio_Calificacion
    FROM Producto_Digital P
    JOIN Juego_Base BG ON P.ID_Producto = BG.ID_Producto
    JOIN Resena R ON P.ID_Producto = R.ID_Producto
    GROUP BY P.ID_Producto, P.Titulo
), PromedioPlataforma AS (
    -- Paso 4: Calcular el promedio general de calificaciones de toda la plataforma
    -- Se castea a DECIMAL para no perder precisión en la división matemática
    SELECT AVG(CAST(Calificacion_1_10 AS DECIMAL(10,4))) AS Promedio_Global 
    FROM Resena
)

-- Pasos 5, 6, 7 y 8: Filtrar, etiquetar y mostrar resultados
SELECT M.Titulo, M.Total_Resenas, CAST(M.Promedio_Calificacion AS DECIMAL(4,2)) AS Promedio_Calificacion,
    -- Paso 7: Etiquetar mediante CASE ordenado
    CASE 
        WHEN M.Promedio_Calificacion < 4.0 THEN 'Crítico'
        WHEN M.Promedio_Calificacion >= 4.0 AND M.Promedio_Calificacion < 6.0 THEN 'Mixto'
        WHEN M.Promedio_Calificacion >= 6.0 AND M.Promedio_Calificacion < 7.0 THEN 'Divisivo'
        ELSE 'Fuera de rango' -- Opcional, para evidenciar si algún dato escapa de la regla
-- Preguntar al profesor por este caso en especifico ya que en la consulta no dice nada sobre
-- que pasaria si no entra dentro de esos rangos del case (no hay un else explicito)
    END AS Veredicto
FROM MetricasJuego M
CROSS JOIN PromedioPlataforma PP
WHERE M.Total_Resenas >= 20
  AND M.Promedio_Calificacion < PP.Promedio_Global
ORDER BY m.Promedio_Calificacion ASC;

--Consulta 10
WITH ResenasPorJuego AS (
    -- Paso 2 y 3: Contar reseñas y calcular promedio por juego
    SELECT ID_Producto, COUNT(ID_Resena) AS Total_Resenas,
    AVG(CAST(Calificacion_1_10 AS DECIMAL(10,4))) AS Prom_Calificacion
    FROM Resena
    GROUP BY ID_Producto
),
PromedioPorEstudio AS (
    -- Paso 4: Calcular el promedio general de los juegos base de cada estudio
    SELECT BG.ID_Estudio_Dev, AVG(CAST(R.Calificacion_1_10 AS DECIMAL(10,4))) AS Prom_Estudio
    FROM Juego_Base BG
    JOIN Resena R ON BG.ID_Producto = R.ID_Producto
    GROUP BY BG.ID_Estudio_Dev
),
JugadoresPorJuego AS (
    -- Extra: Calcular el total de jugadores que poseen el juego (basado en Biblioteca)
    SELECT ID_Producto, COUNT(ID_Usuario) AS Total_Jugadores
    FROM Biblioteca
    GROUP BY ID_Producto
),
ReputacionGlobal AS (
    -- Paso 7: Calcular la reputación promedio de TODOS los juegos base
    -- Se invoca la función escalar enviando el ID_Producto
    SELECT AVG(CAST(dbo.fn_calcular_reputacion(ID_Producto) AS DECIMAL(12,4))) AS Prom_Reputacion_Global
    FROM Juego_Base
),
JuegosCandidatos AS (
    -- Unificamos la información y aplicamos los filtros a nivel de juego
    SELECT P.ID_Producto, P.Titulo, E.Nombre AS Estudio,
    ISNULL(JPJ.Total_Jugadores, 0) AS Total_Jugadores,
        RPP.Prom_Calificacion,
        -- Paso 6: Invocamos la función para obtener la reputación del juego
        dbo.fn_calcular_reputacion(P.ID_Producto) AS Puntaje_Reputacion
    FROM Juego_Base BG
    JOIN Producto_Digital P ON BG.ID_Producto = P.ID_Producto
    JOIN Empresa_Corporativa E ON BG.ID_Estudio_Dev = E.ID_Empresa
    JOIN ResenasPorJuego RPP ON BG.ID_Producto = RPP.ID_Producto
    LEFT JOIN JugadoresPorJuego JPJ ON BG.ID_Producto = JPJ.ID_Producto
    JOIN PromedioPorEstudio PPE ON BG.ID_Estudio_Dev = PPE.ID_Estudio_Dev
    WHERE 
        -- Paso 1: Que nunca haya recibido un reembolso (Filtro de No Existencia)
        NOT EXISTS (
            SELECT 1 
            FROM Reembolso REM
            WHERE REM.ID_Producto = BG.ID_Producto
        )
        AND RPP.Total_Resenas >= 20 AND RPP.Prom_Calificacion > PPE.Prom_Estudio
)
-- Preguntar si se permite select 1: funciona como un interruptor que devuelve el número 1 al encontrar 
-- una coincidencia, sin gastar recursos extrayendo los datos reales de la tabla. 
-- le indica al motor: "solo verifica si la fila existe, el contenido exacto no importa".

-- Pasos 8, 9 y 10: Comparar con la reputación global, dar formato y ordenar
SELECT JC.Titulo, JC.Estudio, JC.Total_Jugadores,
CAST(JC.Prom_Calificacion AS DECIMAL(4,2)) AS Promedio_Calificacion,
CAST(JC.Puntaje_Reputacion AS DECIMAL(10,2)) AS Puntaje_Reputacion
FROM JuegosCandidatos JC
CROSS JOIN ReputacionGlobal RG
WHERE JC.Puntaje_Reputacion > RG.Prom_Reputacion_Global
ORDER BY JC.Puntaje_Reputacion DESC;

--Consulta 11
WITH EstadisticasBiblioteca AS (
    -- Pasos 1, 4 y 5: Encontrar usuarios con juegos, contar juegos y obtener su última sesión
    -- MAX() para obtener la sesión más reciente entre todos los juegos de su biblioteca
    SELECT ID_Usuario, MAX(Fecha_Ultima_Sesion) AS Fecha_Ultima_Sesion,
    COUNT(ID_Producto) AS Juegos_En_Biblioteca
    FROM Biblioteca
    GROUP BY ID_Usuario
)

-- Paso 6: Mostrar columnas finales
SELECT U.Nickname, EB.Fecha_Ultima_Sesion, EB.Juegos_En_Biblioteca
FROM Usuario U
JOIN EstadisticasBiblioteca EB ON U.ID_Usuario = EB.ID_Usuario
WHERE 
    -- Paso 2: Excluir usuarios que hayan publicado alguna reseña (preguntar por select 1)
    NOT EXISTS (SELECT 1 
        FROM Resena R
        WHERE R.ID_Usuario = U.ID_Usuario
    )
    -- Paso 3: Excluir usuarios que tengan algún logro desbloqueado
    AND NOT EXISTS (
        SELECT 1 
        FROM Desbloqueo_Logro DL
        WHERE DL.ID_Usuario = U.ID_Usuario
    );

--Consulta 12
WITH ProductosUltimoAno AS (
    SELECT ID_Producto, Fecha_Lanzamiento
    FROM Producto_Digital
    WHERE Fecha_Lanzamiento >= DATEADD(year, -1, CAST(GETDATE() AS DATE))
)

SELECT TOP 3 EC.Nombre_Etiqueta, SUM(pe.Cantidad_Votos) AS Votos_Totales, 
COUNT(p.ID_Producto) AS Productos_Asociados
FROM ProductosUltimoAno P
JOIN Producto_Etiqueta PE ON P.ID_Producto = PE.ID_Producto
JOIN Etiqueta_Comunidad EC ON PE.ID_Etiqueta = EC.ID_Etiqueta
GROUP BY EC.ID_Etiqueta, EC.Nombre_Etiqueta
ORDER BY Votos_Totales DESC;

--Consulta 13
WITH TotalLogros AS (
    -- Paso 1: Obtener la cantidad total de logros de cada juego
    SELECT ID_Juego_Base, COUNT(ID_Logro) AS Total_Logros
    FROM Logro
    GROUP BY ID_Juego_Base
),
LogrosUsuario AS (
    -- Paso 2: Obtener cantidad de logros únicos desbloqueados por usuario en cada juego
    SELECT ID_Usuario, ID_Juego_Base, COUNT(DISTINCT ID_Logro) AS Logros_Desbloqueados
    FROM Desbloqueo_Logro
    GROUP BY ID_Usuario, ID_Juego_Base
)

-- Pasos 3, 4, 5 y 6: Comparar, aplicar división, seleccionar y mostrar
SELECT U.Nickname, PD.Titulo AS Titulo_Juego, TL.Total_Logros
FROM LogrosUsuario LU
JOIN TotalLogros TL ON LU.ID_Juego_Base = TL.ID_Juego_Base
JOIN Usuario U ON LU.ID_Usuario = U.ID_Usuario
JOIN Producto_Digital PD ON TL.ID_Juego_Base = PD.ID_Producto
WHERE LU.Logros_Desbloqueados = TL.Total_Logros;
-- Paso 4: División Relacional pura. 
-- Se cumple solo si el subconjunto del usuario es igual al conjunto total del juego.

--Consulta 14
WITH VentasMes AS (
    -- Paso 1, 2, 3 y 4: Calcular el ingreso bruto de Juegos Base en el mes actual
    SELECT 
        BG.ID_Estudio_Dev,
        -- Precio histórico restando su respectivo descuento en la factura
        SUM(DF.Precio_Venta_Historico * (1.0 - (DF.Descuento_Aplicado_Pct / 100.0))) AS Ingreso_Bruto
    FROM Factura F
    JOIN Detalle_Factura DF ON F.ID_Factura = DF.ID_Factura
    JOIN Juego_Base BG ON DF.ID_Producto = BG.ID_Producto
    WHERE YEAR(f.Fecha_Hora_Emision) = YEAR(GETDATE()) AND MONTH(f.Fecha_Hora_Emision) = MONTH(GETDATE())
    GROUP BY BG.ID_Estudio_Dev
),
ReembolsosMes AS (
    -- Paso 5: Calcular los reembolsos de Juegos Base en el mes actual
    SELECT BG.ID_Estudio_Dev, SUM(R.Monto_Reembolsado) AS Reembolsos
    FROM Reembolso R
    JOIN Juego_Base BG ON R.ID_Producto = BG.ID_Producto
    WHERE YEAR(R.Fecha_Reembolso) = YEAR(GETDATE()) 
      AND MONTH(R.Fecha_Reembolso) = MONTH(GETDATE())
    GROUP BY BG.ID_Estudio_Dev
),
LiquidacionEstudios AS (
    -- Paso 6, 7 y 8: Unificar datos, calcular neto e invocar la función de clasificación
    SELECT EC.Nombre AS Estudio, EC.Pais_Origen, VM.Ingreso_Bruto,
    ISNULL(RM.Reembolsos, 0.0) AS Reembolsos,
    (VM.Ingreso_Bruto - ISNULL(RM.Reembolsos, 0.0)) AS Ingreso_Neto,
    dbo.fn_clasificar_ingreso(VM.Ingreso_Bruto) AS Tramo_Comision,
        -- Asignamos la tasa de comisión mediante CASE basado en la función
    CASE dbo.fn_clasificar_ingreso(VM.Ingreso_Bruto)
        WHEN 'AAA' THEN 0.30
        WHEN 'Consolidado' THEN 0.25
        WHEN 'Indie' THEN 0.20
    END AS Tasa_Comision
    FROM VentasMes VM
    JOIN Empresa_Corporativa EC ON VM.ID_Estudio_Dev = EC.ID_Empresa
    LEFT JOIN ReembolsosMes RM ON VM.ID_Estudio_Dev = RM.ID_Estudio_Dev
),
MontoFinal AS (
    -- Paso 9: Calcular el monto exacto a pagar al estudio (restando la comisión de la plataforma)
    SELECT Estudio, Pais_Origen, Ingreso_Bruto, Reembolsos, Ingreso_Neto, Tramo_Comision, Tasa_Comision,
    -- El estudio recibe el Ingreso Neto menos el % de comisión
    (Ingreso_Neto * (1.0 - Tasa_Comision)) AS Monto_A_Pagar
    FROM LiquidacionEstudios
),
PromedioPagos AS (
    -- Paso 10: Calcular el promedio general de todos los montos a pagar este mes
    SELECT AVG(Monto_A_Pagar) AS Promedio_Monto_A_Pagar
    FROM MontoFinal
)

-- Paso 11 y 12: Formatear y mostrar solo los superiores al promedio
SELECT MF.Estudio, MF.Pais_Origen, CAST(MF.Ingreso_Bruto AS DECIMAL(12,2)) AS Ingreso_Bruto,
CAST(MF.Reembolsos AS DECIMAL(12,2)) AS Reembolsos,
CAST(MF.Ingreso_Neto AS DECIMAL(12,2)) AS Ingreso_Neto,
MF.Tramo_Comision,
-- Formatear la comisión para que se vea como '30%', '25%', etc, PREGUNTAR SOBRE EL USO DE VARCHAR
-- es un tipo de dato en SQL diseñado para almacenar cadenas de texto. se uso para convertir 
-- los cálculos numéricos en texto, lo que permite concatenarles el símbolo '%' (ej. '15.5%') 
-- sin que el motor arroje un error matemático.
CAST(CAST(MF.Tasa_Comision * 100 AS INT) AS VARCHAR(5)) + '%' AS Comision,
CAST(MF.Monto_A_Pagar AS DECIMAL(12,2)) AS Monto_A_Pagar
FROM MontoFinal MF
CROSS JOIN PromedioPagos PP
WHERE MF.Monto_A_Pagar > PP.Promedio_Monto_A_Pagar
ORDER BY MF.Monto_A_Pagar DESC;

--Consulta 15
WITH BaseSims4 AS (
    -- Paso 1: Encontrar el ID del juego base 'Los Sims 4'
    SELECT ID_Producto 
    FROM Producto_Digital 
    WHERE Titulo = N'Los Sims 4' AND Tipo_Producto = 'Juego_Base'
),
DLCsSims4 AS (
    -- Paso 2: Encontrar los IDs de sus DLCs asociados
    SELECT D.ID_Producto 
    FROM DLC D
    JOIN BaseSims4 BS ON D.ID_Juego_Base = BS.ID_Producto
),
UsuariosBase AS (
    -- Paso 3: Usuarios que poseen el juego base en su Biblioteca
    SELECT B.ID_Usuario 
    FROM Biblioteca B
    JOIN BaseSims4 BS ON B.ID_Producto = BS.ID_Producto
),
UsuariosDLCs AS (
    -- Paso 4 y 5: Contar DLCs comprados por usuario y filtrar al menos 5
    SELECT F.ID_Usuario, COUNT(DISTINCT df.ID_Producto) AS Cantidad_DLCs
    FROM Factura F
    JOIN Detalle_Factura DF ON F.ID_Factura = DF.ID_Factura
    JOIN DLCsSims4 DLC ON DF.ID_Producto = DLC.ID_Producto
    GROUP BY F.ID_Usuario
    HAVING COUNT(DISTINCT DF.ID_Producto) >= 5
),
UsuariosMods AS (
    -- Paso 6 y 7: Contar mods suscritos del juego base y filtrar al menos 1
    SELECT MS.ID_Usuario, COUNT(MS.ID_Mod) AS Mods_Suscritos
    FROM Suscripcion_Mod MS
    JOIN BaseSims4 BS ON MS.ID_Producto_Base = BS.ID_Producto
    GROUP BY MS.ID_Usuario
    HAVING COUNT(MS.ID_Mod) >= 1
),
FranquiciaCompleta AS (
    -- CTE Auxiliar: Unificar todos los IDs de la franquicia (Juego Base + DLCs)
    SELECT ID_Producto 
    FROM BaseSims4
    UNION ALL
    SELECT ID_Producto 
    FROM DLCsSims4
),
GastosUsuario AS (
    -- Paso 8: Sumar pagos totales en la franquicia aplicando el descuento exacto
    SELECT F.ID_Usuario, 
    SUM(DF.Precio_Venta_Historico * (1.0 - (DF.Descuento_Aplicado_Pct / 100.0))) AS Total_Gastado
    FROM Factura F
    JOIN Detalle_Factura DF ON F.ID_Factura = DF.ID_Factura
    JOIN FranquiciaCompleta FC ON DF.ID_Producto = FC.ID_Producto
    GROUP BY F.ID_Usuario
),
ReembolsosUsuario AS (
    -- Paso 9: Sumar reembolsos de la franquicia por usuario
    SELECT F.ID_Usuario, SUM(R.Monto_Reembolsado) AS Total_Reembolsado
    FROM Reembolso R
    JOIN Factura F ON R.ID_Factura = F.ID_Factura
    JOIN FranquiciaCompleta FC ON R.ID_Producto = FC.ID_Producto
    GROUP BY F.ID_Usuario
)

-- Pasos 10 y 11: Unir los filtros, calcular el dinero final y mostrar
SELECT U.Nickname, UDLC.Cantidad_DLCs, UM.Mods_Suscritos,
-- Dinero Invertido: Gasto bruto menos los posibles reembolsos
CAST(ISNULL(GU.Total_Gastado, 0.0) - ISNULL(RU.Total_Reembolsado, 0.0) AS DECIMAL(12,2)) 
AS Dinero_Invertido
FROM UsuariosBase UB
JOIN Usuario U ON UB.ID_Usuario = U.ID_Usuario
JOIN UsuariosDLCs UDLC ON UB.ID_Usuario = UDLC.ID_Usuario
JOIN UsuariosMods UM ON UB.ID_Usuario = UM.ID_Usuario
LEFT JOIN GastosUsuario GU ON UB.ID_Usuario = GU.ID_Usuario
LEFT JOIN ReembolsosUsuario RU ON ub.ID_Usuario = RU.ID_Usuario
ORDER BY Dinero_Invertido DESC;

--Consulta 16
WITH Overcooked AS (
    -- Paso 1: Encontrar el ID del producto 'Overcooked'
    SELECT ID_Producto
    FROM Producto_Digital
    WHERE Titulo = N'Overcooked'
),
UsuariosOvercooked AS (
    -- Paso 2 y 7: Encontrar usuarios que lo poseen y obtener sus horas jugadas
    SELECT B.ID_Usuario, B.Horas_Jugadas
    FROM Biblioteca B
    JOIN Overcooked O ON B.ID_Producto = O.ID_Producto
),
AmistadesBidireccionales AS (
    -- Paso 3 y 4: Obtener amistades aceptadas y tratarlas como bidireccionales
    -- UNION automáticamente elimina duplicados
    SELECT ID_Usuario_Solicitante AS ID_Usuario, ID_Usuario_Receptor AS ID_Amigo
    FROM Amistad_Usuario
    WHERE Estado_Amistad = 'Aceptada'
    UNION
    SELECT ID_Usuario_Receptor AS ID_Usuario, ID_Usuario_Solicitante AS ID_Amigo
    FROM Amistad_Usuario
    WHERE Estado_Amistad = 'Aceptada'
),
RedAmigosOvercooked AS (
    -- Paso 5 y 6: Verificar cuáles amigos activos poseen Overcooked y contarlos
    SELECT AB.ID_Usuario, COUNT(AB.ID_Amigo) AS Amigos_Con_Juego
    FROM AmistadesBidireccionales AB
    -- El amigo debe poseer el juego (cruzamos con la CTE de dueños del juego):
    JOIN UsuariosOvercooked UO_F ON AB.ID_Amigo = UO_F.ID_Usuario
    -- El amigo debe ser un usuario con cuenta activa:
    JOIN Usuario UF ON AB.ID_Amigo = UF.ID_Usuario
    WHERE UF.Estado_Cuenta = 'Activa'
    GROUP BY AB.ID_Usuario
)

-- Paso 8, 9 y 10: Filtrar >= 2, ordenar descendentemente y mostrar columnas
SELECT U.Nickname, UO.Horas_Jugadas, RA.Amigos_Con_Juego
FROM UsuariosOvercooked UO
JOIN Usuario U ON UO.ID_Usuario = U.ID_Usuario
JOIN RedAmigosOvercooked RA ON UO.ID_Usuario = RA.ID_Usuario
WHERE RA.Amigos_Con_Juego >= 2
ORDER BY RA.Amigos_Con_Juego DESC;

--Consulta 17
WITH PromedioPrecios AS (
    -- Paso 1: Calcular el promedio general de precios solo de los Juegos Base
    SELECT AVG(PD.Precio_Base_Actual) AS Promedio_General
    FROM Producto_Digital PD
    JOIN Juego_Base BG ON PD.ID_Producto = BG.ID_Producto
),
VentasFullPrice AS (
    -- Paso 3: Contar las ventas de cada producto donde NO hubo descuento (Descuento = 0)
    SELECT ID_Producto, COUNT(ID_Factura) AS Ventas_Full_Price
    FROM Detalle_Factura
    WHERE Descuento_Aplicado_Pct = 0
    GROUP BY ID_Producto
),
IdiomasPorJuego AS (
    -- Paso 5: Contar cuántos idiomas distintos soporta cada producto
    SELECT ID_Producto, COUNT(ID_Idioma) AS Idiomas_Soportados
    FROM Soporte_Idioma
    GROUP BY ID_Producto
)

-- Pasos 2, 4, 6 y 7: Unir todo, aplicar los filtros solicitados y mostrar columnas
SELECT P.Titulo, P.Precio_Base_Actual, I.Idiomas_Soportados, V.Ventas_Full_Price
FROM Producto_Digital P
JOIN Juego_Base BG ON P.ID_Producto = BG.ID_Producto
JOIN VentasFullPrice V ON P.ID_Producto = V.ID_Producto
JOIN IdiomasPorJuego I ON P.ID_Producto = I.ID_Producto
CROSS JOIN PromedioPrecios PP
WHERE P.Precio_Base_Actual > PP.Promedio_General AND v.Ventas_Full_Price > 50 
AND i.Idiomas_Soportados >= 4
ORDER BY v.Ventas_Full_Price DESC;

--Consulta 18
WITH JerarquiaCorporativa AS (
    -- Pasos 1, 2, 3 y 4: Ancla - Subsidiarias DIRECTAS de una Empresa Matriz
    SELECT MAIN.Nombre AS Empresa_Matriz_Principal,SUB.ID_Empresa AS ID_Subsidiaria,
        SUB.Nombre AS Empresa_Subsidiaria, 1 AS Nivel_Jerarquia
    FROM Empresa_Corporativa SUB
    -- INNER JOIN para excluir independientes (las que no son ni matriz ni subsidiaria)
    JOIN Empresa_Corporativa MAIN ON SUB.ID_Empresa_Matriz = MAIN.ID_Empresa
    WHERE MAIN.ID_Empresa_Matriz IS NULL -- Condición: El padre debe ser la cima de la pirámide
    UNION ALL
    -- Paso 5 y 6: Parte Recursiva - Subsidiarias INDIRECTAS (hijas de las hijas)
    SELECT JC.Empresa_Matriz_Principal, SUB.ID_Empresa, SUB.Nombre, JC.Nivel_Jerarquia + 1
    FROM Empresa_Corporativa SUB
    -- El paso recursivo referencia a la propia CTE
    JOIN JerarquiaCorporativa JC ON SUB.ID_Empresa_Matriz = JC.ID_Subsidiaria
),
ProductosPorEstudio AS (
    -- CTE Auxiliar: Unir Juegos Base y DLCs para saber qué ID_Producto desarrolló cada empresa
    SELECT ID_Estudio_Dev AS ID_Empresa, ID_Producto
    FROM Juego_Base
    UNION ALL
    SELECT BG.ID_Estudio_Dev AS ID_Empresa, D.ID_Producto
    FROM DLC D
    JOIN Juego_Base BG ON D.ID_Juego_Base = BG.ID_Producto
),
ConteoProductos AS (
    -- Paso 7: Contar la cantidad total de productos (Juegos + DLCs) desarrollados
    SELECT ID_Empresa, COUNT(ID_Producto) AS Productos_Desarrollados
    FROM ProductosPorEstudio
    GROUP BY ID_Empresa
),
VentasMes AS (
    -- Paso 8: Calcular ventas del mes actual de esos productos
    SELECT PPE.ID_Empresa, 
    SUM(DF.Precio_Venta_Historico * (1.0 - (DF.Descuento_Aplicado_Pct / 100.0))) AS Ingreso_Bruto
    FROM Factura F
    JOIN Detalle_Factura DF ON F.ID_Factura = DF.ID_Factura
    JOIN ProductosPorEstudio PPE ON DF.ID_Producto = PPE.ID_Producto
    WHERE YEAR(F.Fecha_Hora_Emision) = YEAR(GETDATE()) AND MONTH(F.Fecha_Hora_Emision) = MONTH(GETDATE())
    GROUP BY PPE.ID_Empresa
),
ReembolsosMes AS (
    -- Paso 9: Calcular reembolsos del mes actual de esos productos
    SELECT PPE.ID_Empresa, SUM(R.Monto_Reembolsado) AS Total_Reembolsado
    FROM Reembolso R
    JOIN ProductosPorEstudio PPE ON R.ID_Producto = PPE.ID_Producto
    WHERE YEAR(R.Fecha_Reembolso) = YEAR(GETDATE()) AND MONTH(r.Fecha_Reembolso) = MONTH(GETDATE())
    GROUP BY PPE.ID_Empresa
)

-- Pasos 10 y 11: Calcular el ingreso neto mensual y mostrar
SELECT JC.Empresa_Matriz_Principal, JC.Empresa_Subsidiaria, JC.Nivel_Jerarquia,
ISNULL(PC.Productos_Desarrollados, 0) AS Productos_Desarrollados,
    -- Ingreso Neto = Bruto - Reembolsos
CAST(ISNULL(VM.Ingreso_Bruto, 0.0) - ISNULL(RM.Total_Reembolsado, 0.0) AS DECIMAL(12,2)) 
AS Ingreso_Neto_Mensual
FROM JerarquiaCorporativa JC
LEFT JOIN ConteoProductos PC ON JC.ID_Subsidiaria = PC.ID_Empresa
LEFT JOIN VentasMes VM ON JC.ID_Subsidiaria = VM.ID_Empresa
LEFT JOIN ReembolsosMes RM ON JC.ID_Subsidiaria = RM.ID_Empresa
ORDER BY JC.Empresa_Matriz_Principal, JC.Nivel_Jerarquia ASC, Ingreso_Neto_Mensual DESC;

--Consulta 19
WITH LogrosPorJuego AS (
    -- Pasos 3 y 5: Contar logros totales del juego y excluir los que tienen 0 (HAVING)
    SELECT ID_Juego_Base AS ID_Producto, COUNT(ID_Logro) AS Total_Logros
    FROM Logro
    GROUP BY ID_Juego_Base
    HAVING COUNT(ID_Logro) > 0
),
LogrosDesbloqueadosUsuario AS (
    -- Paso 4: Contar logros desbloqueados por cada usuario en cada juego
    SELECT ID_Usuario, ID_Juego_Base AS ID_Producto, COUNT(ID_Logro) AS Cantidad_Logros_Desbloqueados
    FROM Desbloqueo_Logro
    GROUP BY ID_Usuario, ID_Juego_Base
)
-- Pasos 1, 2, 6, 7 y 8: Unificar, calcular porcentaje y mostrar
SELECT U.Nickname, P.Titulo, R.Calificacion_1_10,
ISNULL(LU.Cantidad_Logros_Desbloqueados, 0) AS Cantidad_Logros_Desbloqueados,
LJ.Total_Logros
FROM Resena R
JOIN Juego_Base BG ON R.ID_Producto = BG.ID_Producto
JOIN Producto_Digital P ON R.ID_Producto = P.ID_Producto
JOIN Usuario U ON R.ID_Usuario = U.ID_Usuario
JOIN LogrosPorJuego LJ ON R.ID_Producto = LJ.ID_Producto
-- LEFT JOIN para mantener a los usuarios que tienen 0 logros desbloqueados
LEFT JOIN LogrosDesbloqueadosUsuario LU ON R.ID_Usuario = LU.ID_Usuario 
AND R.ID_Producto = LU.ID_Producto
WHERE R.Calificacion_1_10 < 4
    -- Paso 6 y 7: Calcular porcentaje de avance y filtrar los menores al 10%
AND (ISNULL(LU.Cantidad_Logros_Desbloqueados, 0) * 100.0 / LJ.Total_Logros) < 10.0
-- La consulta no dice si hay que ordenarlo pero por si acaso se puede ordenar
ORDER BY R.Calificacion_1_10 ASC;
-- Quitar ORDER BY si no ven necesario hacerlo

--Consulta 20
DECLARE @ID_Usuario INT = 1; -- Reemplaza el 1 por el ID que desees probar
-- 1 en este caso reemplaza a (<valor>) que sale en la instruccion del github

WITH AmistadesBidireccionales AS (
    -- Pasos 4 y 5: Interpretar relación como bidireccional y amistades aceptadas
    SELECT ID_Usuario_Solicitante AS U1, ID_Usuario_Receptor AS U2
    FROM Amistad_Usuario
    WHERE Estado_Amistad = 'Aceptada'
    UNION
    SELECT ID_Usuario_Receptor, ID_Usuario_Solicitante
    FROM Amistad_Usuario
    WHERE Estado_Amistad = 'Aceptada'
),
RedAmigos AS (
    -- Paso 3 y 6: CTE Recursiva - Empezar desde el usuario indicado (Ancla)
    SELECT U2 AS ID_Contacto, 1 AS Grado
    FROM AmistadesBidireccionales
    WHERE U1 = @ID_Usuario
    UNION ALL
    -- Pasos 7 y 8: Recorrer hasta 3 grados y evitar ciclos infinitos limitando la profundidad
    SELECT AB.U2, RA.Grado + 1
    FROM AmistadesBidireccionales AB
    JOIN RedAmigos RA ON AB.U1 = RA.ID_Contacto
    WHERE RA.Grado < 3
),
ContactosMinimos AS (
    -- Pasos 9 y 10: Calcular grado mínimo de separación y excluir al usuario de origen
    SELECT ID_Contacto, MIN(Grado) AS Grado_Separacion
    FROM RedAmigos
    WHERE ID_Contacto <> @ID_Usuario
    GROUP BY ID_Contacto
),
JuegosRecomendables AS (
    -- Pasos 11, 12, 13 y 14: Clasificar, obtener juegos base, excluir los del origen y contar
    SELECT CM.ID_Contacto, CM.Grado_Separacion,
    CASE CM.Grado_Separacion
        WHEN 1 THEN 'Amigo directo'
        WHEN 2 THEN 'Amigo de un amigo'
        WHEN 3 THEN 'Contacto lejano'
    END AS Cercania,
    COUNT(DISTINCT B.ID_Producto) AS Juegos_Recomendables
    FROM ContactosMinimos CM
    JOIN Biblioteca B ON CM.ID_Contacto = B.ID_Usuario
    JOIN Juego_Base BG ON B.ID_Producto = BG.ID_Producto
    WHERE NOT EXISTS (
        -- Paso 13: El Anti-Join. Excluye si el usuario origen ya lo tiene
        SELECT 1 
        FROM Biblioteca BTC 
        WHERE BTC.ID_Usuario = @ID_Usuario AND BTC.ID_Producto = B.ID_Producto
    )
    GROUP BY CM.ID_Contacto, CM.Grado_Separacion
)
-- Pasos 15, 16, 17 y 18: Filtrar, ordenar y mostrar
SELECT U.Nickname AS Nickname_Contacto, JR.Grado_Separacion, JR.Cercania, JR.Juegos_Recomendables
FROM JuegosRecomendables JR
JOIN Usuario U ON JR.ID_Contacto = U.ID_Usuario
WHERE JR.Juegos_Recomendables >= 1
ORDER BY JR.Grado_Separacion ASC, JR.Juegos_Recomendables DESC;
