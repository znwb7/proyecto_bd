USE ConeSTeamDB;
GO
/*
 Programmability.sql
 PARTE 1: FUNCIONES ESCALARES (UDF)
 ----------------------------------------------------------------------------
 1. fn_calcular_impuesto(@monto)
 Objetivo: Calcula el impuesto sobre las ventas (IVA del 16%).
 ---------------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION dbo.fn_calcular_impuesto (@monto DECIMAL(10,2))
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @tasa_iva DECIMAL(4,2) = 0.16; -- 16% IVA parametrizable
    RETURN ROUND(ISNULL(@monto, 0.00) * @tasa_iva, 2);
END;
GO

-- ----------------------------------------------------------------------------
-- 2. fn_precio_con_descuento(@ID_Producto, @fecha)
-- Objetivo: Devuelve el precio final que tenía o tiene un producto en una fecha dada.
-- Justificación para la defensa:
-- Consulta en Historial_Descuento si la fecha indicada cayó dentro de una oferta.
-- Si hubo oferta, calcula el descuento sobre 'Precio_Base_En_Evento' (precio congelado
-- al iniciar la oferta). Si no hubo oferta, devuelve el 'Precio_Base_Actual'.
-- ----------------------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_precio_con_descuento (
    @ID_Producto INT,
    @fecha DATE
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @precio_final DECIMAL(10,2);
    DECLARE @precio_base_evento DECIMAL(10,2);
    DECLARE @porcentaje_descuento INT;

    -- Buscar descuento vigente para la fecha indicada
    SELECT TOP 1 
        @precio_base_evento = Precio_Base_En_Evento,
        @porcentaje_descuento = Porcentaje_Descuento
    FROM Historial_Descuento
    WHERE ID_Producto = @ID_Producto
      AND @fecha BETWEEN Fecha_Inicio AND Fecha_Fin
    ORDER BY Porcentaje_Descuento DESC;

    -- Si hay evento de descuento activo
    IF @precio_base_evento IS NOT NULL
    BEGIN
        SET @precio_final = ROUND(@precio_base_evento * (1.00 - (@porcentaje_descuento / 100.00)), 2);
    END
    ELSE
    BEGIN
        -- Si no hay descuento, devolver el precio base actual
        SELECT @precio_final = Precio_Base_Actual
        FROM Producto_Digital
        WHERE ID_Producto = @ID_Producto;
    END

    RETURN ISNULL(@precio_final, 0.00);
END;
GO

-- ----------------------------------------------------------------------------
-- 3. fn_clasificar_ingreso(@monto)
-- Objetivo: Clasifica financieramente a un estudio desarrollador según sus ingresos.
-- Justificación para la defensa:
-- > 10.000 USD       -> 'AAA'
-- 2.000 a 10.000 USD -> 'Consolidado'
-- < 2.000 USD        -> 'Indie'
-- ----------------------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_clasificar_ingreso (@monto DECIMAL(12,2))
RETURNS NVARCHAR(20)
AS
BEGIN
    IF @monto > 10000.00
        RETURN N'AAA';
    IF @monto >= 2000.00
        RETURN N'Consolidado';
    RETURN N'Indie';
END;
GO

-- ----------------------------------------------------------------------------
-- 4. fn_calcular_reputacion(@ID_Producto)
-- Objetivo: Calcula el índice de reputación de un producto (0 a 100).
-- Justificación para la defensa:
-- Aplica la fórmula requerida por el enunciado:
-- Reputación = (Promedio_Reseñas * 7) + (Metacritic * 0.2) + (Total_Jugadores * 0.05)
-- Si la suma supera 100, se fija en 100.00 como tope máximo.
-- ----------------------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_calcular_reputacion (@ID_Producto INT)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @promedio_resenas DECIMAL(5,2) = 0.00;
    DECLARE @metacritic DECIMAL(5,2) = 0.00;
    DECLARE @total_jugadores INT = 0;
    DECLARE @puntaje DECIMAL(5,2) = 0.00;

    -- Promedio de calificación de las reseñas (1 a 10)
    SELECT @promedio_resenas = ISNULL(AVG(CAST(Calificacion_1_10 AS DECIMAL(5,2))), 0.00)
    FROM Resena
    WHERE ID_Producto = @ID_Producto;

    -- Metacritic registrado en Producto_Digital (0 a 100)
    SELECT @metacritic = ISNULL(CAST(Metacritic_Score AS DECIMAL(5,2)), 0.00)
    FROM Producto_Digital
    WHERE ID_Producto = @ID_Producto;

    -- Total de jugadores que tienen el producto en su biblioteca
    SELECT @total_jugadores = COUNT(*)
    FROM Biblioteca
    WHERE ID_Producto = @ID_Producto;

    -- Cálculo ponderado según fórmula oficial
    SET @puntaje = (@promedio_resenas * 7.00) + (@metacritic * 0.20) + (@total_jugadores * 0.05);

    -- Aplicar tope máximo de 100
    IF @puntaje > 100.00
        SET @puntaje = 100.00;

    RETURN @puntaje;
END;
GO

-- ----------------------------------------------------------------------------
-- 5. fn_calcular_horas_totales_usuario(@ID_Usuario)
-- Objetivo: Devuelve la suma acumulada de horas jugadas por un usuario.
-- Justificación para la defensa:
-- Suma las Horas_Jugadas de todas las entradas en Biblioteca para ese usuario.
-- Si el usuario no tiene juegos o no registra horas, devuelve 0.00.
-- ----------------------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_calcular_horas_totales_usuario (@ID_Usuario INT)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @total_horas DECIMAL(10,2) = 0.00;

    SELECT @total_horas = ISNULL(SUM(Horas_Jugadas), 0.00)
    FROM Biblioteca
    WHERE ID_Usuario = @ID_Usuario;

    RETURN @total_horas;
END;
GO
-- ============================================================================
-- PARTE 2: DISPARADORES (TRIGGERS) (Punto 15 de Notion)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 15.1 trg_auditoria_precios (Safety)
-- Objetivo: Al actualizar Producto_Digital.Precio_Base_Actual, impedir que el
-- cambio supere el 50% del precio anterior (evita errores de dedo o fraude).
-- Excepción: No aplica si el precio anterior era 0.00 (ej. DLC gratuito).
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_auditoria_precios
ON Producto_Digital
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Solo evaluamos si se modificó la columna Precio_Base_Actual
    IF UPDATE(Precio_Base_Actual)
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM inserted i
            JOIN deleted d ON i.ID_Producto = d.ID_Producto
            WHERE d.Precio_Base_Actual > 0.00
              AND ABS(i.Precio_Base_Actual - d.Precio_Base_Actual) > (d.Precio_Base_Actual * 0.50)
        )
        BEGIN
            RAISERROR('Operación cancelada: El cambio de precio supera el 50%% permitido respecto al valor anterior.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END
    END
END;
GO

-- ----------------------------------------------------------------------------
-- 15.2 trg_proteccion_menores (Rating)
-- Objetivo: Antes de insertar en Detalle_Factura, si el producto tiene clasificación
-- 'M' o 'AO', verificar la edad del comprador. Si es menor de 18 años, cancelar
-- con el mensaje exacto: 'Contenido restringido por edad'.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_proteccion_menores
ON Detalle_Factura
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Factura f ON i.ID_Factura = f.ID_Factura
        JOIN Usuario u ON f.ID_Usuario = u.ID_Usuario
        JOIN Producto_Digital p ON i.ID_Producto = p.ID_Producto
        WHERE p.Clasificacion_Edad IN ('M', 'AO')
          AND DATEDIFF(YEAR, u.Fecha_Nacimiento, GETDATE()) - 
              CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, u.Fecha_Nacimiento, GETDATE()), u.Fecha_Nacimiento) > GETDATE() THEN 1 ELSE 0 END < 18
    )
    BEGIN
        RAISERROR('Contenido restringido por edad', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

-- ----------------------------------------------------------------------------
-- 15.3 trg_poblado_biblioteca
-- Objetivo: Después de insertar en Detalle_Factura, insertar automáticamente
-- el producto en la Biblioteca del usuario comprador con Horas_Jugadas = 0,
-- si aún no lo tiene.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_poblado_biblioteca
ON Detalle_Factura
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Biblioteca (ID_Usuario, ID_Producto, Horas_Jugadas, Fecha_Ultima_Sesion)
    SELECT DISTINCT f.ID_Usuario, i.ID_Producto, 0.00, NULL
    FROM inserted i
    JOIN Factura f ON i.ID_Factura = f.ID_Factura
    WHERE NOT EXISTS (
        SELECT 1 
        FROM Biblioteca b 
        WHERE b.ID_Usuario = f.ID_Usuario 
          AND b.ID_Producto = i.ID_Producto
    );
END;
GO

-- ----------------------------------------------------------------------------
-- 15.4 trg_reembolso_revocacion
-- Objetivo: Después de registrar un reembolso en la tabla Reembolso, revocar
-- el acceso eliminando el producto de la Biblioteca del usuario.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_reembolso_revocacion
ON Reembolso
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE b
    FROM Biblioteca b
    JOIN inserted i ON b.ID_Producto = i.ID_Producto
    JOIN Factura f ON i.ID_Factura = f.ID_Factura
    WHERE b.ID_Usuario = f.ID_Usuario;
END;
GO

-- ----------------------------------------------------------------------------
-- 15.5 trg_validaciones_carrito
-- Objetivo: Al intentar agregar a Carrito:
--   1. Impedir si el usuario ya posee el producto en su Biblioteca.
--   2. Si es un DLC, exigir que el Juego_Base esté en Biblioteca o en el mismo Carrito.
-- Si viola alguna regla, levantar error con RAISERROR y cancelar.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_validaciones_carrito
ON Carrito
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Regla 1: No puede agregar lo que ya posee en Biblioteca
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Biblioteca b ON i.ID_Usuario = b.ID_Usuario AND i.ID_Producto = b.ID_Producto
    )
    BEGIN
        RAISERROR('Operación cancelada: El usuario ya posee este producto en su biblioteca.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Regla 2: Si es un DLC, debe poseer el Juego Base en Biblioteca o tenerlo en el Carrito
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN DLC d ON i.ID_Producto = d.ID_Producto
        WHERE NOT EXISTS (
            SELECT 1 FROM Biblioteca b
            WHERE b.ID_Usuario = i.ID_Usuario AND b.ID_Producto = d.ID_Juego_Base
        )
        AND NOT EXISTS (
            SELECT 1 FROM Carrito c
            WHERE c.ID_Usuario = i.ID_Usuario AND c.ID_Producto = d.ID_Juego_Base
        )
    )
    BEGIN
        RAISERROR('Operación cancelada: Para comprar un DLC debe poseer el juego base en su biblioteca o incluirlo en el carrito.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO
-- ============================================================================
-- PARTE 3: PROCEDIMIENTOS ALMACENADOS (Punto 16 de Notion)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 16.1 sp_realizar_compra
-- Objetivo: Simula el proceso de compra de los ítems en el carrito del usuario.
-- Parámetros: @ID_Usuario INT, @ID_Metodo_Pago INT
-- Lógica:
--   1. Valida existencia de usuario, método de pago y que el carrito tenga productos.
--   2. Valida que el usuario no posea ya en su biblioteca ninguno de los productos.
--   3. Aplica descuentos vigentes y calcula Sub_Total, Descuentos, IVA y Total.
--   4. Inserta Factura y Detalle_Factura (los triggers validan edad y pueblan biblioteca).
--   5. Vacía el carrito del usuario y confirma la transacción.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_realizar_compra
    @ID_Usuario INT,
    @ID_Metodo_Pago INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Validaciones preliminares
    IF NOT EXISTS (SELECT 1 FROM Usuario WHERE ID_Usuario = @ID_Usuario)
    BEGIN
        RAISERROR('Error: El usuario especificado no existe.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM Metodo_Pago WHERE ID_Metodo_Pago = @ID_Metodo_Pago)
    BEGIN
        RAISERROR('Error: El método de pago especificado no existe.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM Carrito WHERE ID_Usuario = @ID_Usuario)
    BEGIN
        RAISERROR('Error: El carrito del usuario está vacío.', 16, 1);
        RETURN;
    END

    -- Validar que no posea ya ningún producto del carrito en su biblioteca
    IF EXISTS (
        SELECT 1 
        FROM Carrito c
        JOIN Biblioteca b ON c.ID_Usuario = b.ID_Usuario AND c.ID_Producto = b.ID_Producto
        WHERE c.ID_Usuario = @ID_Usuario
    )
    BEGIN
        RAISERROR('Error: El usuario ya posee uno o más productos del carrito en su biblioteca.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Fecha_Hoy DATE = CAST(GETDATE() AS DATE);

        -- Tabla temporal para calcular los precios de cada ítem en el carrito
        DECLARE @Items TABLE (
            ID_Producto INT,
            Precio_Base DECIMAL(10,2),
            Precio_Final DECIMAL(10,2),
            Descuento_Pct INT
        );

        INSERT INTO @Items (ID_Producto, Precio_Base, Precio_Final, Descuento_Pct)
        SELECT 
            p.ID_Producto,
            p.Precio_Base_Actual,
            dbo.fn_precio_con_descuento(p.ID_Producto, @Fecha_Hoy) AS Precio_Final,
            ISNULL((
                SELECT TOP 1 hd.Porcentaje_Descuento
                FROM Historial_Descuento hd
                WHERE hd.ID_Producto = p.ID_Producto
                  AND @Fecha_Hoy BETWEEN hd.Fecha_Inicio AND hd.Fecha_Fin
                ORDER BY hd.Porcentaje_Descuento DESC
            ), 0) AS Descuento_Pct
        FROM Carrito c
        JOIN Producto_Digital p ON c.ID_Producto = p.ID_Producto
        WHERE c.ID_Usuario = @ID_Usuario;

        -- Cálculos financieros consolidados
        DECLARE @Sub_Total DECIMAL(10,2);
        DECLARE @Monto_Descuento DECIMAL(10,2);
        DECLARE @Base_Imponible DECIMAL(10,2);
        DECLARE @Monto_Impuesto DECIMAL(10,2);
        DECLARE @Total_Pagado DECIMAL(10,2);

        SELECT 
            @Sub_Total = SUM(Precio_Base),
            @Base_Imponible = SUM(Precio_Final),
            @Monto_Descuento = SUM(Precio_Base - Precio_Final)
        FROM @Items;

        -- Impuesto calculado mediante la función fn_calcular_impuesto (IVA 16%)
        SET @Monto_Impuesto = dbo.fn_calcular_impuesto(@Base_Imponible);
        SET @Total_Pagado = @Base_Imponible + @Monto_Impuesto;

        -- Generar código de transacción único
        DECLARE @Codigo_Tx NVARCHAR(50) = N'TXN-' + CONVERT(NVARCHAR(8), GETDATE(), 112) + N'-' + 
                                          CAST(@ID_Usuario AS NVARCHAR(10)) + N'-' + 
                                          SUBSTRING(CAST(NEWID() AS NVARCHAR(36)), 1, 8);

        -- 1. Insertar Factura
        INSERT INTO Factura (
            Codigo_Transaccion, Fecha_Hora_Emision, 
            Sub_Total, Monto_Descuento, Monto_Impuesto, Total_Pagado, 
            ID_Usuario, ID_Metodo_Pago
        )
        VALUES (
            @Codigo_Tx, GETDATE(), 
            @Sub_Total, @Monto_Descuento, @Monto_Impuesto, @Total_Pagado, 
            @ID_Usuario, @ID_Metodo_Pago
        );

        DECLARE @Nuevo_ID_Factura INT = SCOPE_IDENTITY();

        -- 2. Insertar Detalle_Factura (Trigger de menores y biblioteca se activan aquí)
        INSERT INTO Detalle_Factura (ID_Factura, ID_Producto, Precio_Venta_Historico, Descuento_Aplicado_Pct)
        SELECT @Nuevo_ID_Factura, ID_Producto, Precio_Final, Descuento_Pct
        FROM @Items;

        -- 3. Vaciar el carrito del usuario
        DELETE FROM Carrito WHERE ID_Usuario = @ID_Usuario;

        COMMIT TRANSACTION;

        SELECT 
            @Nuevo_ID_Factura AS ID_Factura_Generada,
            @Codigo_Tx AS Codigo_Transaccion,
            @Total_Pagado AS Total_Cobrado,
            'Compra realizada exitosamente y productos agregados a la biblioteca.' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 16.2 sp_dashboard_estudio
-- Objetivo: Genera 3 conjuntos de resultados (Result Sets) para el análisis
--           financiero y comercial de un estudio desarrollador en un periodo.
-- Parámetros: @ID_Empresa INT, @Fecha_Inicio DATE, @Fecha_Fin DATE
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_dashboard_estudio
    @ID_Empresa INT,
    @Fecha_Inicio DATE,
    @Fecha_Fin DATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Empresa_Corporativa WHERE ID_Empresa = @ID_Empresa)
    BEGIN
        RAISERROR('Error: La empresa especificada no existe.', 16, 1);
        RETURN;
    END

    -- TABLA 1: KPIs (Ingreso total, unidades vendidas, reembolsos del periodo)
    SELECT 
        e.Nombre AS Estudio,
        ISNULL(SUM(df.Precio_Venta_Historico), 0.00) AS Ingreso_Bruto,
        ISNULL((
            SELECT SUM(r.Monto_Reembolsado)
            FROM Reembolso r
            JOIN Juego_Base jb_r ON r.ID_Producto = jb_r.ID_Producto
            WHERE jb_r.ID_Estudio_Dev = @ID_Empresa
              AND r.Fecha_Reembolso BETWEEN @Fecha_Inicio AND @Fecha_Fin
        ), 0.00) AS Total_Reembolsado,
        ISNULL(SUM(df.Precio_Venta_Historico), 0.00) - ISNULL((
            SELECT SUM(r.Monto_Reembolsado)
            FROM Reembolso r
            JOIN Juego_Base jb_r ON r.ID_Producto = jb_r.ID_Producto
            WHERE jb_r.ID_Estudio_Dev = @ID_Empresa
              AND r.Fecha_Reembolso BETWEEN @Fecha_Inicio AND @Fecha_Fin
        ), 0.00) AS Ingreso_Neto,
        COUNT(df.ID_Producto) AS Unidades_Vendidas
    FROM Empresa_Corporativa e
    LEFT JOIN Juego_Base jb ON e.ID_Empresa = jb.ID_Estudio_Dev
    LEFT JOIN Detalle_Factura df ON jb.ID_Producto = df.ID_Producto
    LEFT JOIN Factura f ON df.ID_Factura = f.ID_Factura 
                        AND CAST(f.Fecha_Hora_Emision AS DATE) BETWEEN @Fecha_Inicio AND @Fecha_Fin
    WHERE e.ID_Empresa = @ID_Empresa
    GROUP BY e.Nombre;

    -- TABLA 2: Sus 5 juegos más vendidos en el periodo
    SELECT TOP 5
        pd.Titulo,
        COUNT(df.ID_Factura) AS Unidades_Vendidas,
        SUM(df.Precio_Venta_Historico) AS Ingreso_Generado
    FROM Juego_Base jb
    JOIN Producto_Digital pd ON jb.ID_Producto = pd.ID_Producto
    JOIN Detalle_Factura df ON pd.ID_Producto = df.ID_Producto
    JOIN Factura f ON df.ID_Factura = f.ID_Factura
    WHERE jb.ID_Estudio_Dev = @ID_Empresa
      AND CAST(f.Fecha_Hora_Emision AS DATE) BETWEEN @Fecha_Inicio AND @Fecha_Fin
    GROUP BY pd.Titulo
    ORDER BY Unidades_Vendidas DESC, Ingreso_Generado DESC;

    -- TABLA 3: Sus 5 mejores compradores (por gasto en juegos del estudio)
    SELECT TOP 5
        u.Nickname,
        u.Pais_Residencia,
        SUM(df.Precio_Venta_Historico) AS Gasto_Total
    FROM Factura f
    JOIN Usuario u ON f.ID_Usuario = u.ID_Usuario
    JOIN Detalle_Factura df ON f.ID_Factura = df.ID_Factura
    JOIN Juego_Base jb ON df.ID_Producto = jb.ID_Producto
    WHERE jb.ID_Estudio_Dev = @ID_Empresa
      AND CAST(f.Fecha_Hora_Emision AS DATE) BETWEEN @Fecha_Inicio AND @Fecha_Fin
    GROUP BY u.Nickname, u.Pais_Residencia
    ORDER BY Gasto_Total DESC;
END;
GO

-- ----------------------------------------------------------------------------
-- 16.3 sp_publicar_producto_con_etiquetas
-- Objetivo: Da de alta un nuevo producto (Juego_Base o DLC) y procesa una
--           cadena de etiquetas separadas por comas en una transacción atómica.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_publicar_producto_con_etiquetas
    -- Atributos generales de Producto_Digital
    @Titulo NVARCHAR(150),
    @Descripcion_Corta NVARCHAR(255),
    @Descripcion_Larga NVARCHAR(MAX),
    @Fecha_Lanzamiento DATE,
    @Tamano_GB DECIMAL(6,2),
    @Clasificacion_Edad NVARCHAR(5),
    @Precio_Base_Actual DECIMAL(10,2),
    @Tipo_Producto NVARCHAR(20),       -- 'Juego_Base' o 'DLC'
    @Metacritic_Score INT,
    -- Atributos para Juego_Base (opcionales si es DLC)
    @ID_Estudio_Dev INT = NULL,
    @ID_Publisher INT = NULL,
    @Motor_Grafico NVARCHAR(100) = NULL,
    @Tiene_Compras_InGame BIT = 0,
    @Soporta_Cloud_Saves BIT = 1,
    -- Atributos para DLC (opcionales si es Juego_Base)
    @ID_Juego_Base INT = NULL,
    @Tipo_Contenido NVARCHAR(20) = NULL,
    @Subtipo_Jugable NVARCHAR(20) = NULL,
    -- Cadena de etiquetas separadas por comas (ej. 'RPG, Souls, Indie')
    @Lista_Etiquetas NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Tipo_Producto NOT IN ('Juego_Base', 'DLC')
    BEGIN
        RAISERROR('Error: Tipo_Producto debe ser "Juego_Base" o "DLC".', 16, 1);
        RETURN;
    END

    IF @Tipo_Producto = 'DLC' AND NOT EXISTS (SELECT 1 FROM Juego_Base WHERE ID_Producto = @ID_Juego_Base)
    BEGIN
        RAISERROR('Error: Todo DLC debe estar vinculado a un Juego_Base existente.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Insertar en Producto_Digital
        INSERT INTO Producto_Digital (
            Titulo, Descripcion_Corta, Descripcion_Larga, 
            Fecha_Lanzamiento, Tamano_GB, Clasificacion_Edad, 
            Precio_Base_Actual, Tipo_Producto, Metacritic_Score
        )
        VALUES (
            @Titulo, @Descripcion_Corta, @Descripcion_Larga, 
            @Fecha_Lanzamiento, @Tamano_GB, @Clasificacion_Edad, 
            @Precio_Base_Actual, @Tipo_Producto, @Metacritic_Score
        );

        DECLARE @Nuevo_ID_Producto INT = SCOPE_IDENTITY();

        -- 2. Insertar en la subtabla correspondiente
        IF @Tipo_Producto = 'Juego_Base'
        BEGIN
            INSERT INTO Juego_Base (
                ID_Producto, ID_Estudio_Dev, ID_Publisher, 
                Motor_Grafico, Tiene_Compras_InGame, Soporta_Cloud_Saves
            )
            VALUES (
                @Nuevo_ID_Producto, @ID_Estudio_Dev, @ID_Publisher, 
                @Motor_Grafico, @Tiene_Compras_InGame, @Soporta_Cloud_Saves
            );
        END
        ELSE
        BEGIN
            INSERT INTO DLC (ID_Producto, ID_Juego_Base, Tipo_Contenido, Subtipo_Jugable)
            VALUES (@Nuevo_ID_Producto, @ID_Juego_Base, @Tipo_Contenido, @Subtipo_Jugable);
        END

        -- 3. Procesar las etiquetas separadas por comas
        IF @Lista_Etiquetas IS NOT NULL AND LEN(TRIM(@Lista_Etiquetas)) > 0
        BEGIN
            DECLARE @TagActual NVARCHAR(100);
            DECLARE @ID_Etiqueta INT;

            DECLARE cursor_tags CURSOR LOCAL FAST_FORWARD FOR
            SELECT DISTINCT TRIM(value) 
            FROM STRING_SPLIT(@Lista_Etiquetas, ',')
            WHERE LEN(TRIM(value)) > 0;

            OPEN cursor_tags;
            FETCH NEXT FROM cursor_tags INTO @TagActual;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                -- Buscar si ya existe la etiqueta; si no, crearla
                SELECT @ID_Etiqueta = ID_Etiqueta 
                FROM Etiqueta_Comunidad 
                WHERE Nombre_Etiqueta = @TagActual;

                IF @ID_Etiqueta IS NULL
                BEGIN
                    INSERT INTO Etiqueta_Comunidad (Nombre_Etiqueta) VALUES (@TagActual);
                    SET @ID_Etiqueta = SCOPE_IDENTITY();
                END

                -- Vincular producto con etiqueta
                IF NOT EXISTS (SELECT 1 FROM Producto_Etiqueta WHERE ID_Producto = @Nuevo_ID_Producto AND ID_Etiqueta = @ID_Etiqueta)
                BEGIN
                    INSERT INTO Producto_Etiqueta (ID_Producto, ID_Etiqueta, Cantidad_Votos)
                    VALUES (@Nuevo_ID_Producto, @ID_Etiqueta, 1);
                END

                FETCH NEXT FROM cursor_tags INTO @TagActual;
            END

            CLOSE cursor_tags;
            DEALLOCATE cursor_tags;
        END

        COMMIT TRANSACTION;

        SELECT @Nuevo_ID_Producto AS ID_Producto_Creado, 'Producto y etiquetas registrados exitosamente.' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @Msg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Msg, 16, 1);
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 16.4 sp_procesar_reembolso
-- Objetivo: Registra una devolución cumpliendo las políticas de la plataforma:
--   1. La compra debe tener menos de 14 días.
--   2. El usuario debe haber jugado menos de 2 horas.
--   3. El Trigger 4 se encarga automáticamente de revocar el acceso en Biblioteca.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_procesar_reembolso
    @ID_Factura INT,
    @ID_Producto INT,
    @Motivo NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    -- Validar que la factura y el producto existan en los detalles
    IF NOT EXISTS (SELECT 1 FROM Detalle_Factura WHERE ID_Factura = @ID_Factura AND ID_Producto = @ID_Producto)
    BEGIN
        RAISERROR('Error: El producto especificado no forma parte de la factura indicada.', 16, 1);
        RETURN;
    END

    -- Validar que no se haya reembolsado previamente esa misma línea
    IF EXISTS (SELECT 1 FROM Reembolso WHERE ID_Factura = @ID_Factura AND ID_Producto = @ID_Producto)
    BEGIN
        RAISERROR('Error: Este producto ya ha sido reembolsado anteriormente.', 16, 1);
        RETURN;
    END

    -- Obtener datos de la compra y del usuario
    DECLARE @ID_Usuario INT;
    DECLARE @Fecha_Compra DATETIME2;
    DECLARE @Precio_Pagado DECIMAL(10,2);
    DECLARE @Horas_Jugadas DECIMAL(6,2) = 0.00;

    SELECT 
        @ID_Usuario = f.ID_Usuario,
        @Fecha_Compra = f.Fecha_Hora_Emision,
        @Precio_Pagado = df.Precio_Venta_Historico
    FROM Factura f
    JOIN Detalle_Factura df ON f.ID_Factura = df.ID_Factura
    WHERE f.ID_Factura = @ID_Factura AND df.ID_Producto = @ID_Producto;

    -- 1. Regla de los 14 días
    IF DATEDIFF(DAY, @Fecha_Compra, GETDATE()) > 14
    BEGIN
        RAISERROR('Error: La compra supera el periodo de garantía de 14 días para reembolsos.', 16, 1);
        RETURN;
    END

    -- 2. Regla de las 2 horas de juego en Biblioteca
    SELECT @Horas_Jugadas = Horas_Jugadas
    FROM Biblioteca
    WHERE ID_Usuario = @ID_Usuario AND ID_Producto = @ID_Producto;

    IF @Horas_Jugadas >= 2.00
    BEGIN
        RAISERROR('Error: El usuario ha jugado 2 horas o más a este título, no aplica reembolso.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Registrar el reembolso (Trigger 15.4 eliminará el producto de Biblioteca)
        INSERT INTO Reembolso (ID_Factura, ID_Producto, Fecha_Reembolso, Monto_Reembolsado, Motivo)
        VALUES (@ID_Factura, @ID_Producto, CAST(GETDATE() AS DATE), @Precio_Pagado, @Motivo);

        COMMIT TRANSACTION;

        SELECT 
            @ID_Factura AS ID_Factura,
            @ID_Producto AS ID_Producto,
            @Precio_Pagado AS Monto_Devuelto,
            'Reembolso aprobado y procesado. Acceso revocado en biblioteca.' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Err, 16, 1);
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 16.5 sp_desbloquear_logro
-- Objetivo: Registra el desbloqueo de un logro de un juego para un usuario.
-- Validaciones:
--   1. El logro debe existir y pertenecer al juego base indicado.
--   2. El usuario debe poseer el juego en su Biblioteca.
--   3. El logro no debe haber sido desbloqueado previamente por ese usuario.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_desbloquear_logro
    @ID_Usuario INT,
    @ID_Juego_Base INT,
    @ID_Logro INT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Validar existencia y pertenencia del logro
    IF NOT EXISTS (SELECT 1 FROM Logro WHERE ID_Juego_Base = @ID_Juego_Base AND ID_Logro = @ID_Logro)
    BEGIN
        RAISERROR('Error: El logro no existe o no pertenece al juego base especificado.', 16, 1);
        RETURN;
    END

    -- 2. Validar que el usuario posea el juego en su biblioteca
    IF NOT EXISTS (SELECT 1 FROM Biblioteca WHERE ID_Usuario = @ID_Usuario AND ID_Producto = @ID_Juego_Base)
    BEGIN
        RAISERROR('Error: El usuario no posee este juego en su biblioteca.', 16, 1);
        RETURN;
    END

    -- 3. Validar que no esté desbloqueado previamente
    IF EXISTS (
        SELECT 1 
        FROM Desbloqueo_Logro 
        WHERE ID_Usuario = @ID_Usuario 
          AND ID_Juego_Base = @ID_Juego_Base 
          AND ID_Logro = @ID_Logro
    )
    BEGIN
        RAISERROR('Error: El usuario ya ha desbloqueado este logro previamente.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Desbloqueo_Logro (ID_Usuario, ID_Juego_Base, ID_Logro, Fecha_Desbloqueo)
        VALUES (@ID_Usuario, @ID_Juego_Base, @ID_Logro, GETDATE());

        COMMIT TRANSACTION;

        SELECT 
            @ID_Usuario AS ID_Usuario,
            @ID_Juego_Base AS ID_Juego_Base,
            @ID_Logro AS ID_Logro,
            'Logro desbloqueado exitosamente.' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMsg, 16, 1);
    END CATCH
END;
GO
