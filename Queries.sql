/* Queries.sql: consultas de reporte de ConeSTeamDB
   Bloque 1 (Cálculos, Fechas, Texto y CASE básicos): Consultas 1, 3, 5, 8, 12
   Bloque 2 (Subconsultas, Agregaciones dobles y Anti-Joins): Consultas 2, 6, 7, 9, 10, 11, 14, 17, 19
   Bloque 3 (Casos de negocio específicos y Retención): Consultas 4, 15, 16
   Bloque 4 (División Relacional y CTEs Recursivas): Consultas 13, 18, 20 */

USE ConeSTeamDB;

/* Parámetro de la Consulta 20 */
DECLARE @ID_Usuario INT = 1; /* Reemplaza el 1 por el ID que desees probar */

/* Consulta 1. Clasificación de Estudios por Facturación. Listar los estudios desarrolladores
   según sus ingresos del último mes, usando la función fn_clasificar_ingreso
   para etiquetarlos.
   – Columnas: Estudio, Pais_Origen, Juegos_Vendidos, Ingreso_Total,
   Clasificacion. */
/* Juegos_Vendidos cuenta las copias vendidas. Ingreso_Total suma lo cobrado por cada copia
   (Precio_Venta_Historico ya lleva el descuento aplicado) y la función clasifica ese total */
SELECT
    E.Nombre AS Estudio,
    E.Pais_Origen,
    COUNT(*) AS Juegos_Vendidos,
    SUM(DF.Precio_Venta_Historico) AS Ingreso_Total,
    dbo.fn_clasificar_ingreso(SUM(DF.Precio_Venta_Historico)) AS Clasificacion

/* Una fila por copia vendida: factura -> detalle -> juego base -> estudio.
   El JOIN con Juego_Base deja fuera los DLC, que no tienen estudio propio */
FROM Factura F
JOIN Detalle_Factura DF ON F.ID_Factura = DF.ID_Factura
JOIN Juego_Base JB ON DF.ID_Producto = JB.ID_Producto
JOIN Empresa_Corporativa E ON JB.ID_Estudio_Dev = E.ID_Empresa

/* Último mes: ventana móvil desde hace un mes hasta ahora */
WHERE F.Fecha_Hora_Emision >= DATEADD(MONTH, -1, GETDATE())

/* Una fila por estudio; el ID evita mezclar dos estudios con el mismo nombre */
GROUP BY E.ID_Empresa, E.Nombre, E.Pais_Origen
ORDER BY Ingreso_Total DESC;

/* Consulta 2. Éxito por Categoría. Para cada Categoría Oficial, mostrar el producto con mayor
   Puntaje_Popularidad, definido comoÑ 
   (Unidades_Vendidas * 2) + (Total_Reseñas * 1.5) + Metacritic_Score
   – Columnas: Nombre_Categoria, Titulo, Estudio, Puntaje_Popularidad. */
/* Puntaje de cada producto en cada una de sus categorías. Las subconsultas cuentan sus ventas
   y reseñas (COUNT da 0 si no tiene); un producto sin Metacritic suma 0 */
WITH DatosProductos AS (
    SELECT
        C.ID_Categoria,
        C.Nombre_Categoria,
        P.Titulo,
        E.Nombre AS Estudio,
        (SELECT COUNT(*) FROM Detalle_Factura DF WHERE DF.ID_Producto = P.ID_Producto) * 2
        + (SELECT COUNT(*) FROM Resena R WHERE R.ID_Producto = P.ID_Producto) * 1.5
        + ISNULL(P.Metacritic_Score, 0) AS Puntaje_Popularidad
    FROM Juego_Categoria JC
    JOIN Categoria_Oficial C ON JC.ID_Categoria = C.ID_Categoria
    JOIN Producto_Digital P ON JC.ID_Producto = P.ID_Producto
    /* El estudio es el del juego base: el propio producto, o el suyo si es un DLC */
    LEFT JOIN DLC D ON P.ID_Producto = D.ID_Producto
    JOIN Juego_Base JB ON JB.ID_Producto = ISNULL(D.ID_Juego_Base, P.ID_Producto)
    JOIN Empresa_Corporativa E ON JB.ID_Estudio_Dev = E.ID_Empresa
)

/* El ganador de cada categoría es el que no tiene ningún rival con más puntaje;
   si hay empate en el máximo, salen todos los empatados */
SELECT DP.Nombre_Categoria, DP.Titulo, DP.Estudio, DP.Puntaje_Popularidad
FROM DatosProductos DP
WHERE NOT EXISTS (
    SELECT 1
    FROM DatosProductos Rival
    WHERE Rival.ID_Categoria = DP.ID_Categoria
      AND Rival.Puntaje_Popularidad > DP.Puntaje_Popularidad
)
ORDER BY Puntaje_Popularidad DESC;

/* Consulta 3. Análisis de Dominios de Correo. Contar la frecuencia de proveedores de correo;
   mostrar solo los dominios con más de 10 usuarios.
   – Columnas: Dominio (ej. gmail.com), Cantidad_Usuarios. */
/* CHARINDEX da la posición de la '@'; SUBSTRING corta desde el carácter siguiente.
   LEN(Correo) como longitud basta para llegar siempre al final del texto */
SELECT
    SUBSTRING(Correo, CHARINDEX('@', Correo) + 1, LEN(Correo)) AS Dominio,
    COUNT(*) AS Cantidad_Usuarios
FROM Usuario
/* Se repite la expresión porque GROUP BY se ejecuta antes que el SELECT y no conoce el alias */
GROUP BY SUBSTRING(Correo, CHARINDEX('@', Correo) + 1, LEN(Correo))
/* HAVING filtra grupos ya contados; WHERE no puede usar COUNT */
HAVING COUNT(*) > 10
ORDER BY Cantidad_Usuarios DESC;

/* Consulta 4. Recompra Temprana (retención). Usuarios cuya segunda compra ocurrió
   dentro de los 30 días siguientes a la primera. Reportar el número de días entre
   ambas.
   – Columnas: Nickname, Fecha_Primera_Compra, Fecha_Segunda_Compra,
   Dias_Entre_Compras. */
/* Primera compra: la fecha más antigua de cada usuario */
WITH PrimeraCompra AS (
    SELECT ID_Usuario, MIN(Fecha_Hora_Emision) AS Fecha_Primera_Compra
    FROM Factura
    GROUP BY ID_Usuario
),
/* Segunda compra: la más antigua de las posteriores a la primera.
   El JOIN deja fuera a quien solo tiene una compra */
SegundaCompra AS (
    SELECT F.ID_Usuario, MIN(F.Fecha_Hora_Emision) AS Fecha_Segunda_Compra
    FROM Factura F
    JOIN PrimeraCompra PC ON F.ID_Usuario = PC.ID_Usuario
    WHERE F.Fecha_Hora_Emision > PC.Fecha_Primera_Compra
    GROUP BY F.ID_Usuario
)

/* DATEDIFF(DAY) cuenta días de calendario entre ambas fechas. Se repite en el WHERE
   porque el WHERE se ejecuta antes que el SELECT y no conoce el alias */
SELECT
    U.Nickname,
    CAST(PC.Fecha_Primera_Compra AS DATE) AS Fecha_Primera_Compra,
    CAST(SC.Fecha_Segunda_Compra AS DATE) AS Fecha_Segunda_Compra,
    DATEDIFF(DAY, PC.Fecha_Primera_Compra, SC.Fecha_Segunda_Compra) AS Dias_Entre_Compras
FROM PrimeraCompra PC
JOIN SegundaCompra SC ON PC.ID_Usuario = SC.ID_Usuario
JOIN Usuario U ON PC.ID_Usuario = U.ID_Usuario
WHERE DATEDIFF(DAY, PC.Fecha_Primera_Compra, SC.Fecha_Segunda_Compra) <= 30
ORDER BY Dias_Entre_Compras ASC;

/* Consulta 5. Peso del Catálogo por Estudio. Sumar el Tamano_GB de los Juegos Base
   publicados por cada estudio desarrollador y formatear el total.
   – Columnas: Estudio, Cantidad_Juegos, Peso_Total (ej. '1.2 TB' o '840.5 GB'). */
/* Total en GB por estudio. Tamano_GB está en Producto_Digital; Juego_Base solo dice quién lo desarrolló */
WITH PesoEstudio AS (
    SELECT
        E.Nombre AS Estudio,
        COUNT(*) AS Cantidad_Juegos,
        SUM(P.Tamano_GB) AS Total_GB
    FROM Empresa_Corporativa E
    JOIN Juego_Base JB ON E.ID_Empresa = JB.ID_Estudio_Dev
    JOIN Producto_Digital P ON JB.ID_Producto = P.ID_Producto
    GROUP BY E.ID_Empresa, E.Nombre
)

/* El número se redondea a un decimal y se pasa a texto para poder concatenarle la unidad.
   1 TB = 1024 GB */
SELECT
    Estudio,
    Cantidad_Juegos,
    CASE
        WHEN Total_GB >= 1024.0 THEN CAST(CAST(Total_GB / 1024.0 AS DECIMAL(10,1)) AS VARCHAR(20)) + ' TB'
        ELSE CAST(CAST(Total_GB AS DECIMAL(10,1)) AS VARCHAR(20)) + ' GB'
    END AS Peso_Total
FROM PesoEstudio
ORDER BY Total_GB DESC;

/* Consulta 6. Mapa de Calor Financiero. Facturación neta (ventas − reembolsos) por país del
   comprador y su participación de mercado global.
   – Columnas: Pais, Total_Neto, Share (ej. '15.5%'). */
WITH BrutoPorPais AS (
    /* Ventas por país sin IVA (Sub_Total - Monto_Descuento), igual que los reembolsos. El LEFT JOIN
       mantiene los países sin compras */
    SELECT U.Pais_Residencia AS Pais, ISNULL(SUM(F.Sub_Total - F.Monto_Descuento), 0.0) AS Bruto_Facturas
    FROM Usuario U
    LEFT JOIN Factura F ON U.ID_Usuario = F.ID_Usuario
    GROUP BY U.Pais_Residencia
),
ReembolsosPorPais AS (
    /* Reembolsos por país del comprador */
    SELECT U.Pais_Residencia AS Pais, ISNULL(SUM(R.Monto_Reembolsado), 0.0) AS Total_Reembolsos
    FROM Usuario U
    JOIN Factura F ON U.ID_Usuario = F.ID_Usuario
    JOIN Reembolso R ON F.ID_Factura = R.ID_Factura
    GROUP BY U.Pais_Residencia
),
NetoPorPais AS (
    /* Neto = ventas - reembolsos (ISNULL para los países sin reembolsos) */
    SELECT BPP.Pais, (BPP.Bruto_Facturas - ISNULL(RPP.Total_Reembolsos, 0.0)) AS Total_Neto
    FROM BrutoPorPais BPP
    LEFT JOIN ReembolsosPorPais RPP ON BPP.Pais = RPP.Pais
),
TotalGlobal AS (
    /* Neto global, base del Share */
    SELECT SUM(Total_Neto) AS Global_Neto
    FROM NetoPorPais
)

/* Share = neto del país / neto global, con un decimal*/
SELECT N.Pais, CAST(N.Total_Neto AS DECIMAL(12,2)) AS Total_Neto,
    CAST(CAST(
            CASE 
                WHEN G.Global_Neto = 0 THEN 0.00
                ELSE (N.Total_Neto * 100.0) / G.Global_Neto 
            END AS DECIMAL(5,1)
        ) AS VARCHAR(20)
    ) + '%' AS Share
FROM NetoPorPais N
CROSS JOIN TotalGlobal G
ORDER BY Total_Neto DESC;

/* Consulta 7. Bibliotecas Cruzadas. Usuarios que poseen en su Biblioteca juegos de la
   categoría 'Estrategia' Y de la categoría 'Terror', con un gasto histórico total >
   100 USD.
   – Columnas: Nickname, Gasto_Total_Historico. */
WITH UsuariosEstrategia AS (
    /* Usuarios con al menos un juego de 'Estrategia' en su biblioteca */
    SELECT DISTINCT B.ID_Usuario
    FROM Biblioteca B
    JOIN Juego_Categoria JC ON b.ID_Producto = JC.ID_Producto
    JOIN Categoria_Oficial CO ON JC.ID_Categoria = CO.ID_Categoria
    WHERE CO.Nombre_Categoria = 'Estrategia'
),
UsuariosTerror AS (
    /* Usuarios con al menos un juego de 'Terror' en su biblioteca */
    SELECT DISTINCT B.ID_Usuario
    FROM Biblioteca B
    JOIN Juego_Categoria JC ON B.ID_Producto = JC.ID_Producto
    JOIN Categoria_Oficial CO ON JC.ID_Categoria = CO.ID_Categoria
    WHERE CO.Nombre_Categoria = 'Terror'
),
UsuariosConAmbas AS (
    /* INTERSECT deja solo a los que están en los dos conjuntos */
    SELECT ID_Usuario 
    FROM UsuariosEstrategia
    INTERSECT
    SELECT ID_Usuario 
    FROM UsuariosTerror
),
GastoTotalUsuarios AS (
    /* Gasto histórico: suma de Total_Pagado de todas sus facturas */
    SELECT ID_Usuario, SUM(Total_Pagado) AS Gasto_Total
    FROM Factura
    GROUP BY ID_Usuario
)

SELECT U.Nickname, CAST(G.Gasto_Total AS DECIMAL(12,2)) AS Gasto_Total_Historico
FROM UsuariosConAmbas UA
JOIN Usuario U ON UA.ID_Usuario = U.ID_Usuario
JOIN GastoTotalUsuarios G ON UA.ID_Usuario = G.ID_Usuario
WHERE G.Gasto_Total > 100.00
ORDER BY Gasto_Total_Historico DESC;

/* Consulta 8. Generaciones. Clasificar usuarios por año de nacimiento: 'Gen Z' (> 2000),
   'Millennials' (1981–2000), 'Gen X y anteriores' (< 1981).
   – Columnas: Generacion, Cantidad_Usuarios_Activos, Gasto_Promedio. */
WITH UsuariosClasificados AS (
    SELECT U.ID_Usuario,
        /* Generación según el año de nacimiento */
    CASE 
        WHEN YEAR(U.Fecha_Nacimiento) > 2000 THEN 'Gen Z'
        WHEN YEAR(U.Fecha_Nacimiento) BETWEEN 1981 AND 2000 THEN 'Millennials'
        ELSE 'Gen X y anteriores'
    END AS Generacion,
        ISNULL(F.Gasto_Total_Usuario, 0.0) AS Gasto_Usuario
    FROM Usuario U
    LEFT JOIN (
        SELECT ID_Usuario, SUM(Total_Pagado) AS Gasto_Total_Usuario
        FROM Factura
        GROUP BY ID_Usuario
    ) F ON U.ID_Usuario = F.ID_Usuario
    WHERE U.Estado_Cuenta = 'Activa'
)

/* El promedio incluye a los usuarios activos sin compras (gasto 0) */
SELECT
    Generacion,
    COUNT(*) AS Cantidad_Usuarios_Activos,
    CAST(AVG(Gasto_Usuario) AS DECIMAL(12,2)) AS Gasto_Promedio
FROM UsuariosClasificados
GROUP BY Generacion
ORDER BY Gasto_Promedio DESC;

/* Consulta 9. Juegos Polémicos. Juegos Base con al menos 20 reseñas cuya calificación
   promedio esté por debajo del promedio general de calificaciones de la
   plataforma. Etiquetar con CASE: 'Crítico' (promedio < 4), 'Mixto' (4–5.9),
   'Divisivo' (6–6.9).
   – Columnas: Titulo, Total_Resenas, Promedio_Calificacion, Veredicto. */
WITH MetricasJuego AS (
    /* Reseñas y promedio de cada juego base */
    SELECT P.Titulo, COUNT(R.ID_Resena) AS Total_Resenas,
    AVG(CAST(R.Calificacion_1_10 AS DECIMAL(10,4))) AS Promedio_Calificacion
    FROM Producto_Digital P
    JOIN Juego_Base BG ON P.ID_Producto = BG.ID_Producto
    JOIN Resena R ON P.ID_Producto = R.ID_Producto
    GROUP BY P.ID_Producto, P.Titulo
), PromedioPlataforma AS (
    /* Promedio de todas las reseñas de la plataforma. El CAST evita que AVG de enteros trunque
       decimales */
    SELECT AVG(CAST(Calificacion_1_10 AS DECIMAL(10,4))) AS Promedio_Global 
    FROM Resena
)

SELECT M.Titulo, M.Total_Resenas, CAST(M.Promedio_Calificacion AS DECIMAL(4,2)) AS Promedio_Calificacion,
    CASE 
        WHEN M.Promedio_Calificacion < 4.0 THEN 'Crítico'
        /* Cada WHEN solo se evalúa si los anteriores fallaron, así que basta el límite superior.
           Sin ELSE: un promedio de 7 o más daría NULL (con los datos no ocurre) */
        WHEN M.Promedio_Calificacion < 6.0 THEN 'Mixto'
        WHEN M.Promedio_Calificacion < 7.0 THEN 'Divisivo'
    END AS Veredicto
FROM MetricasJuego M
CROSS JOIN PromedioPlataforma PP
WHERE M.Total_Resenas >= 20
  AND M.Promedio_Calificacion < PP.Promedio_Global
ORDER BY M.Promedio_Calificacion ASC;

/* Consulta 10. Juegos de Élite (ranking exigente). Listar los Juegos Base que cumplan todas
   estas condiciones: (a) nunca han recibido un reembolso; (b) tienen al menos 20
   reseñas; (c) su calificación promedio supera el promedio de calificación de
   todos los Juegos Base de su mismo estudio desarrollador; y (d) su reputación
   (invocando fn_calcular_reputacion) está por encima del promedio de
   reputación de todos los Juegos Base de la plataforma. Ordenar
   descendentemente por reputación.
   – Columnas: Titulo, Estudio, Total_Jugadores, Promedio_Calificacion,
   Puntaje_Reputacion. */
WITH ResenasPorJuego AS (
    /* Reseñas y promedio de cada producto */
    SELECT ID_Producto, COUNT(ID_Resena) AS Total_Resenas,
    AVG(CAST(Calificacion_1_10 AS DECIMAL(10,4))) AS Prom_Calificacion
    FROM Resena
    GROUP BY ID_Producto
),
PromedioPorEstudio AS (
    /* (c) Promedio de todas las reseñas de los juegos base de cada estudio */
    SELECT BG.ID_Estudio_Dev, AVG(CAST(R.Calificacion_1_10 AS DECIMAL(10,4))) AS Prom_Estudio
    FROM Juego_Base BG
    JOIN Resena R ON BG.ID_Producto = R.ID_Producto
    GROUP BY BG.ID_Estudio_Dev
),
JugadoresPorJuego AS (
    /* Jugadores = usuarios que tienen el juego en su biblioteca */
    SELECT ID_Producto, COUNT(ID_Usuario) AS Total_Jugadores
    FROM Biblioteca
    GROUP BY ID_Producto
),
ReputacionGlobal AS (
    /* (d) Reputación media de todos los juegos base */
    SELECT AVG(CAST(dbo.fn_calcular_reputacion(ID_Producto) AS DECIMAL(12,4))) AS Prom_Reputacion_Global
    FROM Juego_Base
),
JuegosCandidatos AS (
    /* Juegos que cumplen (a), (b) y (c) */
    SELECT P.ID_Producto, P.Titulo, E.Nombre AS Estudio,
    ISNULL(JPJ.Total_Jugadores, 0) AS Total_Jugadores,
        RPP.Prom_Calificacion,
        dbo.fn_calcular_reputacion(P.ID_Producto) AS Puntaje_Reputacion
    FROM Juego_Base BG
    JOIN Producto_Digital P ON BG.ID_Producto = P.ID_Producto
    JOIN Empresa_Corporativa E ON BG.ID_Estudio_Dev = E.ID_Empresa
    JOIN ResenasPorJuego RPP ON BG.ID_Producto = RPP.ID_Producto
    LEFT JOIN JugadoresPorJuego JPJ ON BG.ID_Producto = JPJ.ID_Producto
    JOIN PromedioPorEstudio PPE ON BG.ID_Estudio_Dev = PPE.ID_Estudio_Dev
    WHERE 
        /* (a) Ningún reembolso */
        NOT EXISTS (
            SELECT 1 
            FROM Reembolso REM
            WHERE REM.ID_Producto = BG.ID_Producto
        )
        AND RPP.Total_Resenas >= 20 AND RPP.Prom_Calificacion > PPE.Prom_Estudio
)

/* (d) Reputación por encima de la media, de mayor a menor */
SELECT JC.Titulo, JC.Estudio, JC.Total_Jugadores,
CAST(JC.Prom_Calificacion AS DECIMAL(4,2)) AS Promedio_Calificacion,
JC.Puntaje_Reputacion
FROM JuegosCandidatos JC
CROSS JOIN ReputacionGlobal RG
WHERE JC.Puntaje_Reputacion > RG.Prom_Reputacion_Global
ORDER BY JC.Puntaje_Reputacion DESC;

/* Consulta 11. Usuarios “Lurkers”. Usuarios con al menos un juego en su Biblioteca pero sin
   ninguna reseña publicada ni logro desbloqueado.
   – Columnas: Nickname, Fecha_Ultima_Sesion, Juegos_En_Biblioteca. */
WITH EstadisticasBiblioteca AS (
    /* Por usuario: juegos en biblioteca y su sesión más reciente (MAX entre todos sus juegos) */
    SELECT ID_Usuario, MAX(Fecha_Ultima_Sesion) AS Fecha_Ultima_Sesion,
    COUNT(ID_Producto) AS Juegos_En_Biblioteca
    FROM Biblioteca
    GROUP BY ID_Usuario
)

SELECT U.Nickname, EB.Fecha_Ultima_Sesion, EB.Juegos_En_Biblioteca
FROM Usuario U
JOIN EstadisticasBiblioteca EB ON U.ID_Usuario = EB.ID_Usuario
WHERE 
    /* Sin reseñas */
    NOT EXISTS (SELECT 1 
        FROM Resena R
        WHERE R.ID_Usuario = U.ID_Usuario
    )
    /* Sin logros desbloqueados */
    AND NOT EXISTS (
        SELECT 1 
        FROM Desbloqueo_Logro DL
        WHERE DL.ID_Usuario = U.ID_Usuario
    );

/* Consulta 12. Tendencias (Tags). Top 3 etiquetas con más Cantidad_Votos acumulados entre
   productos lanzados en el último año.
   – Columnas: Nombre_Etiqueta, Votos_Totales, Productos_Asociados. */
/* Votos de cada etiqueta sumados solo entre productos lanzados en el último año */
SELECT TOP 3
    EC.Nombre_Etiqueta,
    SUM(PE.Cantidad_Votos) AS Votos_Totales,
    COUNT(*) AS Productos_Asociados
FROM Producto_Digital P
JOIN Producto_Etiqueta PE ON P.ID_Producto = PE.ID_Producto
JOIN Etiqueta_Comunidad EC ON PE.ID_Etiqueta = EC.ID_Etiqueta
WHERE P.Fecha_Lanzamiento >= DATEADD(YEAR, -1, CAST(GETDATE() AS DATE))
GROUP BY EC.ID_Etiqueta, EC.Nombre_Etiqueta
ORDER BY Votos_Totales DESC;

/* Consulta 13. Coleccionistas Completos (cobertura total). Usuarios que han desbloqueado
   todos los logros de al menos un Juego Base (división relacional).
   – Columnas: Nickname, Titulo_Juego, Total_Logros. */
WITH TotalLogros AS (
    /* Logros de cada juego */
    SELECT ID_Juego_Base, COUNT(ID_Logro) AS Total_Logros
    FROM Logro
    GROUP BY ID_Juego_Base
),
LogrosUsuario AS (
    /* Logros distintos que cada usuario desbloqueó en cada juego */
    SELECT ID_Usuario, ID_Juego_Base, COUNT(DISTINCT ID_Logro) AS Logros_Desbloqueados
    FROM Desbloqueo_Logro
    GROUP BY ID_Usuario, ID_Juego_Base
)

/* División relacional: el usuario completó el juego si desbloqueó tantos logros como tiene */
SELECT U.Nickname, PD.Titulo AS Titulo_Juego, TL.Total_Logros
FROM LogrosUsuario LU
JOIN TotalLogros TL ON LU.ID_Juego_Base = TL.ID_Juego_Base
JOIN Usuario U ON LU.ID_Usuario = U.ID_Usuario
JOIN Producto_Digital PD ON TL.ID_Juego_Base = PD.ID_Producto
WHERE LU.Logros_Desbloqueados = TL.Total_Logros;

/* Consulta 14. Liquidación de Regalías (comisión escalonada, neto de reembolsos).
   Calcular el pago mensual a cada estudio desarrollador por las ventas del mes
   actual, considerando:
   – Ingreso bruto = ventas de sus Juegos Base en el mes; menos los
   reembolsos del mes de esos juegos → Ingreso neto.
   – Comisión escalonada según la clasificación del estudio (usar
   fn_clasificar_ingreso sobre el ingreso bruto): 'AAA' → 30%,
   'Consolidado' → 25%, 'Indie' → 20%.
   – Mostrar solo los estudios cuyo monto a pagar supere el promedio de
   los montos a pagar de todos los estudios ese mes.
   – Columnas: Estudio, Pais_Origen, Ingreso_Bruto, Reembolsos, Ingreso_Neto,
   Tramo_Comision, Comision, Monto_A_Pagar. */
WITH VentasMes AS (
    /* Ingreso bruto de juegos base en el mes actual y su tramo. El precio ya lleva el descuento; la
       función clasifica el total una sola vez */
    SELECT
        BG.ID_Estudio_Dev,
        SUM(DF.Precio_Venta_Historico) AS Ingreso_Bruto,
        dbo.fn_clasificar_ingreso(SUM(DF.Precio_Venta_Historico)) AS Tramo_Comision
    FROM Factura F
    JOIN Detalle_Factura DF ON F.ID_Factura = DF.ID_Factura
    JOIN Juego_Base BG ON DF.ID_Producto = BG.ID_Producto
    WHERE YEAR(F.Fecha_Hora_Emision) = YEAR(GETDATE()) AND MONTH(F.Fecha_Hora_Emision) = MONTH(GETDATE())
    GROUP BY BG.ID_Estudio_Dev
),
ReembolsosMes AS (
    /* Reembolsos del mes de esos juegos */
    SELECT BG.ID_Estudio_Dev, SUM(R.Monto_Reembolsado) AS Reembolsos
    FROM Reembolso R
    JOIN Juego_Base BG ON R.ID_Producto = BG.ID_Producto
    WHERE YEAR(R.Fecha_Reembolso) = YEAR(GETDATE()) 
      AND MONTH(R.Fecha_Reembolso) = MONTH(GETDATE())
    GROUP BY BG.ID_Estudio_Dev
),
LiquidacionEstudios AS (
    /* Neto = bruto - reembolsos; la tasa sale del tramo */
    SELECT EC.Nombre AS Estudio, EC.Pais_Origen, VM.Ingreso_Bruto,
    ISNULL(RM.Reembolsos, 0.0) AS Reembolsos,
    (VM.Ingreso_Bruto - ISNULL(RM.Reembolsos, 0.0)) AS Ingreso_Neto,
    VM.Tramo_Comision,
    CASE VM.Tramo_Comision
        WHEN 'AAA' THEN 0.30
        WHEN 'Consolidado' THEN 0.25
        WHEN 'Indie' THEN 0.20
    END AS Tasa_Comision
    FROM VentasMes VM
    JOIN Empresa_Corporativa EC ON VM.ID_Estudio_Dev = EC.ID_Empresa
    LEFT JOIN ReembolsosMes RM ON VM.ID_Estudio_Dev = RM.ID_Estudio_Dev
),
MontoFinal AS (
    /* La comisión de la plataforma sale del neto y el estudio recibe el resto */
    SELECT Estudio, Pais_Origen, Ingreso_Bruto, Reembolsos, Ingreso_Neto, Tramo_Comision,
    (Ingreso_Neto * Tasa_Comision) AS Comision,
    (Ingreso_Neto * (1.0 - Tasa_Comision)) AS Monto_A_Pagar
    FROM LiquidacionEstudios
),
PromedioPagos AS (
    /* Promedio de los montos a pagar del mes */
    SELECT AVG(Monto_A_Pagar) AS Promedio_Monto_A_Pagar
    FROM MontoFinal
)

/* Solo los estudios por encima del promedio */
SELECT
    MF.Estudio,
    MF.Pais_Origen,
    CAST(MF.Ingreso_Bruto AS DECIMAL(12,2)) AS Ingreso_Bruto,
    CAST(MF.Reembolsos AS DECIMAL(12,2)) AS Reembolsos,
    CAST(MF.Ingreso_Neto AS DECIMAL(12,2)) AS Ingreso_Neto,
    MF.Tramo_Comision,
    CAST(MF.Comision AS DECIMAL(12,2)) AS Comision,
    CAST(MF.Monto_A_Pagar AS DECIMAL(12,2)) AS Monto_A_Pagar
FROM MontoFinal MF
CROSS JOIN PromedioPagos PP
WHERE MF.Monto_A_Pagar > PP.Promedio_Monto_A_Pagar
ORDER BY MF.Monto_A_Pagar DESC;

/* Consulta 15. Ecosistema ‘Los Sims 4’. Listar los usuarios que poseen ‘Los Sims 4’ en su
   Biblioteca, han comprado al menos 5 de sus DLCs y están suscritos a por lo
   menos un mod del juego. Calcular el dinero total que el usuario invirtió en la
   franquicia (sumando lo que pagó por el juego base y sus DLCs, y restándole
   cualquier devolución o reembolso). Ordenar los resultados de mayor a menor
   según este gasto.
   – Columnas: Nickname, Cantidad_DLCs, Mods_Suscritos, Dinero_Invertido. */
WITH BaseSims4 AS (
    /* Juego base 'Los Sims 4' */
    SELECT ID_Producto 
    FROM Producto_Digital 
    WHERE Titulo = 'Los Sims 4' AND Tipo_Producto = 'Juego_Base'
),
DLCsSims4 AS (
    /* Sus DLC */
    SELECT D.ID_Producto 
    FROM DLC D
    JOIN BaseSims4 BS ON D.ID_Juego_Base = BS.ID_Producto
),
UsuariosBase AS (
    /* Usuarios que tienen el juego base */
    SELECT B.ID_Usuario 
    FROM Biblioteca B
    JOIN BaseSims4 BS ON B.ID_Producto = BS.ID_Producto
),
UsuariosDLCs AS (
    /* Usuarios que compraron al menos 5 DLC distintos */
    SELECT F.ID_Usuario, COUNT(DISTINCT df.ID_Producto) AS Cantidad_DLCs
    FROM Factura F
    JOIN Detalle_Factura DF ON F.ID_Factura = DF.ID_Factura
    JOIN DLCsSims4 DLC ON DF.ID_Producto = DLC.ID_Producto
    GROUP BY F.ID_Usuario
    HAVING COUNT(DISTINCT DF.ID_Producto) >= 5
),
UsuariosMods AS (
    /* Mods del juego a los que está suscrito cada usuario */
    SELECT MS.ID_Usuario, COUNT(MS.ID_Mod) AS Mods_Suscritos
    FROM Suscripcion_Mod MS
    JOIN BaseSims4 BS ON MS.ID_Producto_Base = BS.ID_Producto
    GROUP BY MS.ID_Usuario
),
FranquiciaCompleta AS (
    /* Todos los productos de la franquicia: juego base + DLC */
    SELECT ID_Producto 
    FROM BaseSims4
    UNION ALL
    SELECT ID_Producto 
    FROM DLCsSims4
),
GastosUsuario AS (
    /* Pagado en la franquicia (el precio ya lleva el descuento) */
    SELECT F.ID_Usuario, SUM(DF.Precio_Venta_Historico) AS Total_Gastado
    FROM Factura F
    JOIN Detalle_Factura DF ON F.ID_Factura = DF.ID_Factura
    JOIN FranquiciaCompleta FC ON DF.ID_Producto = FC.ID_Producto
    GROUP BY F.ID_Usuario
),
ReembolsosUsuario AS (
    /* Reembolsado en la franquicia */
    SELECT F.ID_Usuario, SUM(R.Monto_Reembolsado) AS Total_Reembolsado
    FROM Reembolso R
    JOIN Factura F ON R.ID_Factura = F.ID_Factura
    JOIN FranquiciaCompleta FC ON R.ID_Producto = FC.ID_Producto
    GROUP BY F.ID_Usuario
)

/* Los JOIN exigen las tres condiciones; los LEFT JOIN traen lo pagado y lo reembolsado */
SELECT U.Nickname, UDLC.Cantidad_DLCs, UM.Mods_Suscritos,
/* Dinero invertido = pagado - reembolsado */
CAST(ISNULL(GU.Total_Gastado, 0.0) - ISNULL(RU.Total_Reembolsado, 0.0) AS DECIMAL(12,2)) 
AS Dinero_Invertido
FROM UsuariosBase UB
JOIN Usuario U ON UB.ID_Usuario = U.ID_Usuario
JOIN UsuariosDLCs UDLC ON UB.ID_Usuario = UDLC.ID_Usuario
JOIN UsuariosMods UM ON UB.ID_Usuario = UM.ID_Usuario
LEFT JOIN GastosUsuario GU ON UB.ID_Usuario = GU.ID_Usuario
LEFT JOIN ReembolsosUsuario RU ON ub.ID_Usuario = RU.ID_Usuario
ORDER BY Dinero_Invertido DESC;

/* Consulta 16. Red Cooperativa (‘Overcooked’). Identificar a los usuarios que poseen
   ‘Overcooked’ en su Biblioteca y contar cuántos de sus amigos activos también
   poseen el mismo título. Filtrar para mostrar únicamente a los usuarios que
   tengan al menos 2 amigos disponibles para jugar. Ordenar descendentemente por
   la cantidad de amigos.
   – Columnas: Nickname, Horas_Jugadas, Amigos_Con_Juego. */
WITH Overcooked AS (
    /* Juego 'Overcooked' */
    SELECT ID_Producto
    FROM Producto_Digital
    WHERE Titulo = 'Overcooked'
),
UsuariosOvercooked AS (
    /* Dueños del juego y sus horas jugadas */
    SELECT B.ID_Usuario, B.Horas_Jugadas
    FROM Biblioteca B
    JOIN Overcooked O ON B.ID_Producto = O.ID_Producto
),
AmistadesBidireccionales AS (
    /* Amistades aceptadas en los dos sentidos; UNION quita duplicados */
    SELECT ID_Usuario_Solicitante AS ID_Usuario, ID_Usuario_Receptor AS ID_Amigo
    FROM Amistad_Usuario
    WHERE Estado_Amistad = 'Aceptada'
    UNION
    SELECT ID_Usuario_Receptor AS ID_Usuario, ID_Usuario_Solicitante AS ID_Amigo
    FROM Amistad_Usuario
    WHERE Estado_Amistad = 'Aceptada'
),
RedAmigosOvercooked AS (
    /* Amigos con cuenta activa que también tienen el juego */
    SELECT AB.ID_Usuario, COUNT(AB.ID_Amigo) AS Amigos_Con_Juego
    FROM AmistadesBidireccionales AB
    JOIN UsuariosOvercooked UO_F ON AB.ID_Amigo = UO_F.ID_Usuario
    JOIN Usuario UF ON AB.ID_Amigo = UF.ID_Usuario
    WHERE UF.Estado_Cuenta = 'Activa'
    GROUP BY AB.ID_Usuario
)

/* Al menos 2 amigos con el juego */
SELECT U.Nickname, UO.Horas_Jugadas, RA.Amigos_Con_Juego
FROM UsuariosOvercooked UO
JOIN Usuario U ON UO.ID_Usuario = U.ID_Usuario
JOIN RedAmigosOvercooked RA ON UO.ID_Usuario = RA.ID_Usuario
WHERE RA.Amigos_Con_Juego >= 2
ORDER BY RA.Amigos_Con_Juego DESC;

/* Consulta 17. Éxito a Precio Completo. Se desea conocer qué Juegos Base son tan exitosos y
   esperados que los usuarios los compran sin esperar a que estén en oferta,
   demostrando además un fuerte alcance internacional. Listar el Título y el Precio
   Base Actual de los Juegos Base cuyo precio sea estrictamente mayor al
   promedio general del precio de todos los Juegos Base del catálogo.
   Adicionalmente, el juego debe cumplir con dos condiciones: haber sido vendido
   más de 50 veces sin ningún tipo de descuento (donde el
   Descuento_Aplicado_Pct fue exactamente 0 en la factura) y ofrecer soporte en al
   menos 4 idiomas distintos.
   – Columnas: Titulo, Precio_Base_Actual, Idiomas_Soportados,
   Ventas_Full_Price. */
WITH PromedioPrecios AS (
    /* Precio medio de los juegos base */
    SELECT AVG(PD.Precio_Base_Actual) AS Promedio_General
    FROM Producto_Digital PD
    JOIN Juego_Base BG ON PD.ID_Producto = BG.ID_Producto
),
VentasFullPrice AS (
    /* Ventas sin ningún descuento */
    SELECT ID_Producto, COUNT(ID_Factura) AS Ventas_Full_Price
    FROM Detalle_Factura
    WHERE Descuento_Aplicado_Pct = 0
    GROUP BY ID_Producto
),
IdiomasPorJuego AS (
    /* Idiomas que soporta cada producto */
    SELECT ID_Producto, COUNT(ID_Idioma) AS Idiomas_Soportados
    FROM Soporte_Idioma
    GROUP BY ID_Producto
)

/* Más caro que la media, más de 50 ventas a precio completo y 4 o más idiomas */
SELECT P.Titulo, P.Precio_Base_Actual, I.Idiomas_Soportados, V.Ventas_Full_Price
FROM Producto_Digital P
JOIN Juego_Base BG ON P.ID_Producto = BG.ID_Producto
JOIN VentasFullPrice V ON P.ID_Producto = V.ID_Producto
JOIN IdiomasPorJuego I ON P.ID_Producto = I.ID_Producto
CROSS JOIN PromedioPrecios PP
WHERE P.Precio_Base_Actual > PP.Promedio_General AND v.Ventas_Full_Price > 50 
AND i.Idiomas_Soportados >= 4
ORDER BY v.Ventas_Full_Price DESC;

/* Consulta 18. Imperios Corporativos. Se desea evaluar el peso financiero de los grandes
   conglomerados en el mercado durante el mes actual. Para aquellas empresas que
   actúan como “Empresa Matriz” (la cima de la jerarquía), generar un reporte que
   muestre a la matriz, sus respectivas empresas subsidiarias (ya sean directas o
   indirectas, lo que requiere recursividad), la cantidad total de productos (Juegos
   Base y DLCs) desarrollados por esa subsidiaria y el Ingreso Neto generado por
   dicha subsidiaria en el mes actual (calculado como las ventas del mes menos los
   reembolsos del mes, similar a la liquidación de regalías).
   – Nota: se deben excluir del reporte a las empresas independientes que no
   pertenezcan a ninguna jerarquía.
   – Columnas: Empresa_Matriz_Principal, Empresa_Subsidiaria,
   Nivel_Jerarquia, Productos_Desarrollados, Ingreso_Neto_Mensual. */
WITH JerarquiaCorporativa AS (
    /* Ancla: subsidiarias directas de una matriz principal (empresa sin matriz). El JOIN excluye a las
       independientes */
    SELECT MAIN.Nombre AS Empresa_Matriz_Principal,SUB.ID_Empresa AS ID_Subsidiaria,
        SUB.Nombre AS Empresa_Subsidiaria, 1 AS Nivel_Jerarquia
    FROM Empresa_Corporativa SUB
    JOIN Empresa_Corporativa MAIN ON SUB.ID_Empresa_Matriz = MAIN.ID_Empresa
    WHERE MAIN.ID_Empresa_Matriz IS NULL
    UNION ALL
    /* Parte recursiva: hijas de las subsidiarias ya encontradas, un nivel más abajo */
    SELECT JC.Empresa_Matriz_Principal, SUB.ID_Empresa, SUB.Nombre, JC.Nivel_Jerarquia + 1
    FROM Empresa_Corporativa SUB
    JOIN JerarquiaCorporativa JC ON SUB.ID_Empresa_Matriz = JC.ID_Subsidiaria
),
ProductosPorEstudio AS (
    /* Productos de cada empresa: sus juegos base y los DLC de esos juegos */
    SELECT ID_Estudio_Dev AS ID_Empresa, ID_Producto
    FROM Juego_Base
    UNION ALL
    SELECT BG.ID_Estudio_Dev AS ID_Empresa, D.ID_Producto
    FROM DLC D
    JOIN Juego_Base BG ON D.ID_Juego_Base = BG.ID_Producto
),
ConteoProductos AS (
    /* Productos por empresa */
    SELECT ID_Empresa, COUNT(ID_Producto) AS Productos_Desarrollados
    FROM ProductosPorEstudio
    GROUP BY ID_Empresa
),
VentasMes AS (
    /* Ventas del mes (el precio ya lleva el descuento) */
    SELECT PPE.ID_Empresa, SUM(DF.Precio_Venta_Historico) AS Ingreso_Bruto
    FROM Factura F
    JOIN Detalle_Factura DF ON F.ID_Factura = DF.ID_Factura
    JOIN ProductosPorEstudio PPE ON DF.ID_Producto = PPE.ID_Producto
    WHERE YEAR(F.Fecha_Hora_Emision) = YEAR(GETDATE()) AND MONTH(F.Fecha_Hora_Emision) = MONTH(GETDATE())
    GROUP BY PPE.ID_Empresa
),
ReembolsosMes AS (
    /* Reembolsos del mes */
    SELECT PPE.ID_Empresa, SUM(R.Monto_Reembolsado) AS Total_Reembolsado
    FROM Reembolso R
    JOIN ProductosPorEstudio PPE ON R.ID_Producto = PPE.ID_Producto
    WHERE YEAR(R.Fecha_Reembolso) = YEAR(GETDATE()) AND MONTH(r.Fecha_Reembolso) = MONTH(GETDATE())
    GROUP BY PPE.ID_Empresa
)

/* Ingreso neto mensual = ventas - reembolsos del mes; 0 si no tuvo movimientos */
SELECT JC.Empresa_Matriz_Principal, JC.Empresa_Subsidiaria, JC.Nivel_Jerarquia,
ISNULL(PC.Productos_Desarrollados, 0) AS Productos_Desarrollados,
CAST(ISNULL(VM.Ingreso_Bruto, 0.0) - ISNULL(RM.Total_Reembolsado, 0.0) AS DECIMAL(12,2)) 
AS Ingreso_Neto_Mensual
FROM JerarquiaCorporativa JC
LEFT JOIN ConteoProductos PC ON JC.ID_Subsidiaria = PC.ID_Empresa
LEFT JOIN VentasMes VM ON JC.ID_Subsidiaria = VM.ID_Empresa
LEFT JOIN ReembolsosMes RM ON JC.ID_Subsidiaria = RM.ID_Empresa
ORDER BY JC.Empresa_Matriz_Principal, JC.Nivel_Jerarquia ASC, Ingreso_Neto_Mensual DESC;

/* Consulta 19. Críticos Inexpertos (reseñas sin respaldo). Identificar a los usuarios que han
   publicado una reseña con calificación baja (Calificacion_1_10 menor a 4) para un
   Juego Base, pero que han demostrado muy poco avance en el mismo, definido
   como haber desbloqueado menos del 10% de los logros totales de ese título. Se
   deben excluir de la consulta los juegos que no posean ningún logro registrado
   (total de logros = 0).
   – Columnas: Nickname, Titulo, Calificacion_1_10,
   Cantidad_Logros_Desbloqueados, Total_Logros. */
WITH LogrosPorJuego AS (
    /* Logros de cada juego; el HAVING excluye los juegos sin logros, como pide el enunciado */
    SELECT ID_Juego_Base AS ID_Producto, COUNT(ID_Logro) AS Total_Logros
    FROM Logro
    GROUP BY ID_Juego_Base
    HAVING COUNT(ID_Logro) > 0
),
LogrosDesbloqueadosUsuario AS (
    /* Logros desbloqueados por cada usuario en cada juego */
    SELECT ID_Usuario, ID_Juego_Base AS ID_Producto, COUNT(ID_Logro) AS Cantidad_Logros_Desbloqueados
    FROM Desbloqueo_Logro
    GROUP BY ID_Usuario, ID_Juego_Base
)
/* Reseñas con nota menor a 4 de juegos base, junto al avance de su autor en ese juego */
SELECT U.Nickname, P.Titulo, R.Calificacion_1_10,
ISNULL(LU.Cantidad_Logros_Desbloqueados, 0) AS Cantidad_Logros_Desbloqueados,
LJ.Total_Logros
FROM Resena R
JOIN Juego_Base BG ON R.ID_Producto = BG.ID_Producto
JOIN Producto_Digital P ON R.ID_Producto = P.ID_Producto
JOIN Usuario U ON R.ID_Usuario = U.ID_Usuario
JOIN LogrosPorJuego LJ ON R.ID_Producto = LJ.ID_Producto
/* LEFT JOIN: quien no desbloqueó nada cuenta con 0 logros */
LEFT JOIN LogrosDesbloqueadosUsuario LU ON R.ID_Usuario = LU.ID_Usuario 
AND R.ID_Producto = LU.ID_Producto
WHERE R.Calificacion_1_10 < 4
    /* Avance menor al 10% de los logros del juego */
AND (ISNULL(LU.Cantidad_Logros_Desbloqueados, 0) * 100.0 / LJ.Total_Logros) < 10.0
ORDER BY R.Calificacion_1_10 ASC;

/* Consulta 20. Círculos de Confianza (recomendación por red de amistades). Para un
   usuario dado (parámetro @ID_Usuario), explorar su red de amistades aceptadas
   hasta 3 grados de separación (recursividad sobre Amistad_Usuario, que es una
   relación bidireccional). Para cada contacto alcanzable (excluyendo al propio
   usuario), determinar su grado mínimo de separación y etiquetarlo con un CASE:
   'Amigo directo' (grado 1), 'Amigo de un amigo' (grado 2), 'Contacto lejano'
   (grado 3). Además, contar cuántos Juegos Base posee ese contacto en su
   Biblioteca que el usuario origen no tiene (recomendaciones potenciales).
   Mostrar únicamente los contactos con al menos 1 juego recomendable,
   ordenando por grado (ascendente) y luego por recomendaciones (descendente).
   – Entrega del parámetro: el @ID_Usuario se provee con una variable
   declarada al inicio del script (DECLARE @ID_Usuario INT = <valor>; ), que
   se puede cambiar antes de ejecutar la consulta. (Opcionalmente pueden
   envolver la consulta en un procedimiento almacenado que reciba
   @ID_Usuario como parámetro; ambas formas se aceptan.)
   – Columnas: Nickname_Contacto, Grado_Separacion, Cercania,
   Juegos_Recomendables. */
/* @ID_Usuario se declara al inicio del script */

WITH AmistadesBidireccionales AS (
    /* Amistades aceptadas en los dos sentidos; UNION quita duplicados */
    SELECT ID_Usuario_Solicitante AS U1, ID_Usuario_Receptor AS U2
    FROM Amistad_Usuario
    WHERE Estado_Amistad = 'Aceptada'
    UNION
    SELECT ID_Usuario_Receptor, ID_Usuario_Solicitante
    FROM Amistad_Usuario
    WHERE Estado_Amistad = 'Aceptada'
),
RedAmigos AS (
    /* Ancla: amigos directos del usuario (grado 1) */
    SELECT U2 AS ID_Contacto, 1 AS Grado
    FROM AmistadesBidireccionales
    WHERE U1 = @ID_Usuario
    UNION ALL
    /* Parte recursiva: amigos de los contactos ya encontrados, hasta el grado 3; el límite evita
       ciclos infinitos */
    SELECT AB.U2, RA.Grado + 1
    FROM AmistadesBidireccionales AB
    JOIN RedAmigos RA ON AB.U1 = RA.ID_Contacto
    WHERE RA.Grado < 3
),
ContactosMinimos AS (
    /* Grado mínimo de cada contacto, sin contar al propio usuario */
    SELECT ID_Contacto, MIN(Grado) AS Grado_Separacion
    FROM RedAmigos
    WHERE ID_Contacto <> @ID_Usuario
    GROUP BY ID_Contacto
),
JuegosRecomendables AS (
    /* Etiqueta de cercanía y juegos base del contacto que el usuario no tiene */
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
        /* Excluye los juegos que el usuario ya tiene */
        SELECT 1 
        FROM Biblioteca BTC 
        WHERE BTC.ID_Usuario = @ID_Usuario AND BTC.ID_Producto = B.ID_Producto
    )
    GROUP BY CM.ID_Contacto, CM.Grado_Separacion
)
/* Al menos 1 juego recomendable; orden por grado y luego por recomendaciones */
SELECT U.Nickname AS Nickname_Contacto, JR.Grado_Separacion, JR.Cercania, JR.Juegos_Recomendables
FROM JuegosRecomendables JR
JOIN Usuario U ON JR.ID_Contacto = U.ID_Usuario
WHERE JR.Juegos_Recomendables >= 1
ORDER BY JR.Grado_Separacion ASC, JR.Juegos_Recomendables DESC;
