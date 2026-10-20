USE ConeSTeamDB;
GO

/* PARTE 1: FUNCIONES */

/* fn_calcular_impuesto: IVA del 16% de un monto (0 si es nulo o negativo) */
CREATE OR ALTER FUNCTION dbo.fn_calcular_impuesto (@monto DECIMAL(10,2))
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @tasa_iva DECIMAL(4,2) = 0.16;

    IF @monto IS NULL OR @monto <= 0.00
        RETURN 0.00;

    RETURN ROUND(@monto * @tasa_iva, 2);
END;
GO

/* fn_precio_con_descuento: precio de un producto en una fecha. Con rebaja vigente,
   el porcentaje se aplica sobre el precio congelado del evento; sin ella, precio actual */
CREATE OR ALTER FUNCTION dbo.fn_precio_con_descuento (
    @ID_Producto INT,
    @fecha DATE
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @precio_final DECIMAL(10,2);
    DECLARE @precio_base_evento DECIMAL(10,2);
    DECLARE @porcentaje_descuento DECIMAL(5,2);

    /* Si hay varias rebajas vigentes, la de mayor porcentaje y luego la más reciente */
    SELECT TOP 1
        @precio_base_evento = Precio_Base_En_Evento,
        @porcentaje_descuento = Porcentaje_Descuento
    FROM Historial_Descuento
    WHERE ID_Producto = @ID_Producto
      AND @fecha BETWEEN Fecha_Inicio AND Fecha_Fin
    ORDER BY Porcentaje_Descuento DESC, Fecha_Inicio DESC;

    IF @precio_base_evento IS NOT NULL
    BEGIN
        SET @precio_final = ROUND(@precio_base_evento * (1.00 - (@porcentaje_descuento / 100.00)), 2);
    END
    ELSE
    BEGIN
        SELECT @precio_final = Precio_Base_Actual
        FROM Producto_Digital
        WHERE ID_Producto = @ID_Producto;
    END

    RETURN ISNULL(@precio_final, 0.00);
END;
GO

/* fn_clasificar_ingreso: 'AAA' (> 10.000), 'Consolidado' (2.000 a 10.000), 'Indie' (< 2.000) */
CREATE OR ALTER FUNCTION dbo.fn_clasificar_ingreso (@monto DECIMAL(12,2))
RETURNS NVARCHAR(20)
AS
BEGIN
    IF @monto > 10000.00
        RETURN 'AAA';
    IF @monto >= 2000.00
        RETURN 'Consolidado';
    RETURN 'Indie';
END;
GO

/* fn_calcular_reputacion: (promedio de reseñas * 7) + (Metacritic * 0.2) + (jugadores * 0.05),
   con tope 100. Sin reseñas o sin Metacritic, ese término vale 0 */
CREATE OR ALTER FUNCTION dbo.fn_calcular_reputacion (@ID_Producto INT)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @promedio_resenas DECIMAL(5,2) = 0.00;
    DECLARE @metacritic DECIMAL(5,2) = 0.00;
    DECLARE @total_jugadores INT = 0;
    DECLARE @puntaje DECIMAL(10,2) = 0.00;

    SELECT @promedio_resenas = ISNULL(AVG(CAST(Calificacion_1_10 AS DECIMAL(5,2))), 0.00)
    FROM Resena
    WHERE ID_Producto = @ID_Producto;

    SELECT @metacritic = ISNULL(CAST(Metacritic_Score AS DECIMAL(5,2)), 0.00)
    FROM Producto_Digital
    WHERE ID_Producto = @ID_Producto;

    SELECT @total_jugadores = COUNT(*)
    FROM Biblioteca
    WHERE ID_Producto = @ID_Producto;

    SET @puntaje = (@promedio_resenas * 7.00) + (@metacritic * 0.20) + (@total_jugadores * 0.05);

    IF @puntaje > 100.00
        SET @puntaje = 100.00;

    RETURN CAST(@puntaje AS DECIMAL(5,2));
END;
GO

/* fn_calcular_horas_totales_usuario: suma de las horas jugadas en su biblioteca (0 si no tiene) */
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

/* PARTE 2: TRIGGERS */

/* trg_auditoria_precios: cancela un cambio de precio de más del 50%, salvo si el anterior era 0 */
CREATE OR ALTER TRIGGER dbo.trg_auditoria_precios
ON Producto_Digital
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF UPDATE(Precio_Base_Actual)
    BEGIN
        /* inserted = precio nuevo, deleted = precio anterior */
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

/* trg_proteccion_menores: cancela la compra de un producto M o AO si el comprador
   tenía menos de 18 años en la fecha de la factura */
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
          /* Cumple 18 después del día de la compra */
          AND DATEADD(YEAR, 18, u.Fecha_Nacimiento) > CAST(f.Fecha_Hora_Emision AS DATE)
    )
    BEGIN
        RAISERROR('Contenido restringido por edad', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

/* trg_poblado_biblioteca: añade lo facturado a la biblioteca del comprador, con 0 horas, si no lo tiene */
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

/* trg_reembolso_revocacion: quita de la biblioteca del comprador el producto reembolsado */
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

/* trg_validaciones_carrito: cancela si el usuario ya posee el producto, o si es un DLC
   cuyo juego base no está en su biblioteca ni en su carrito */
CREATE OR ALTER TRIGGER dbo.trg_validaciones_carrito
ON Carrito
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

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

/* PARTE 3: PROCEDIMIENTOS ALMACENADOS */

/* sp_realizar_compra: factura el carrito del usuario con las rebajas vigentes y lo vacía */
CREATE OR ALTER PROCEDURE dbo.sp_realizar_compra
    @ID_Usuario INT,
    @ID_Metodo_Pago INT
AS
BEGIN
    SET NOCOUNT ON;

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

        /* Una sola lectura de la hora para toda la compra */
        DECLARE @Ahora DATETIME2 = GETDATE();
        DECLARE @Fecha_Hoy DATE = CAST(@Ahora AS DATE);

        DECLARE @Items TABLE (
            ID_Producto INT,
            Precio_Base DECIMAL(10,2),
            Precio_Final DECIMAL(10,2),
            Descuento_Pct DECIMAL(10,2)
        );

        /* Por producto: precio de referencia (el del evento si hay rebaja), precio final y porcentaje */
        INSERT INTO @Items (ID_Producto, Precio_Base, Precio_Final, Descuento_Pct)
        SELECT
            p.ID_Producto,
            ISNULL((
                SELECT TOP 1 hd.Precio_Base_En_Evento
                FROM Historial_Descuento hd
                WHERE hd.ID_Producto = p.ID_Producto
                  AND @Fecha_Hoy BETWEEN hd.Fecha_Inicio AND hd.Fecha_Fin
                ORDER BY hd.Porcentaje_Descuento DESC, hd.Fecha_Inicio DESC
            ), p.Precio_Base_Actual) AS Precio_Base,
            dbo.fn_precio_con_descuento(p.ID_Producto, @Fecha_Hoy) AS Precio_Final,
            ISNULL((
                SELECT TOP 1 hd.Porcentaje_Descuento
                FROM Historial_Descuento hd
                WHERE hd.ID_Producto = p.ID_Producto
                  AND @Fecha_Hoy BETWEEN hd.Fecha_Inicio AND hd.Fecha_Fin
                ORDER BY hd.Porcentaje_Descuento DESC, hd.Fecha_Inicio DESC
            ), 0) AS Descuento_Pct
        FROM Carrito c
        JOIN Producto_Digital p ON c.ID_Producto = p.ID_Producto
        WHERE c.ID_Usuario = @ID_Usuario;

        /* Total = Sub_Total - Descuento + IVA */
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

        SET @Monto_Impuesto = dbo.fn_calcular_impuesto(@Base_Imponible);
        SET @Total_Pagado = @Base_Imponible + @Monto_Impuesto;

        /* TRX-AAAAMMDD-usuario-aleatorio */
        DECLARE @Codigo_Tx NVARCHAR(50) = 'TRX-' + CONVERT(NVARCHAR(8), @Ahora, 112) + '-' +
                                          CAST(@ID_Usuario AS NVARCHAR(10)) + '-' +
                                          SUBSTRING(CAST(NEWID() AS NVARCHAR(36)), 1, 8);

        INSERT INTO Factura (
            Codigo_Transaccion, Fecha_Hora_Emision,
            Sub_Total, Monto_Descuento, Monto_Impuesto, Total_Pagado,
            ID_Usuario, ID_Metodo_Pago
        )
        VALUES (
            @Codigo_Tx, @Ahora,
            @Sub_Total, @Monto_Descuento, @Monto_Impuesto, @Total_Pagado,
            @ID_Usuario, @ID_Metodo_Pago
        );

        DECLARE @Nuevo_ID_Factura INT = SCOPE_IDENTITY();

        /* Aquí se disparan los triggers de edad y de biblioteca */
        INSERT INTO Detalle_Factura (ID_Factura, ID_Producto, Precio_Venta_Historico, Descuento_Aplicado_Pct)
        SELECT @Nuevo_ID_Factura, ID_Producto, Precio_Final, Descuento_Pct
        FROM @Items;

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

/* sp_dashboard_estudio: KPIs, 5 juegos más vendidos y 5 mejores compradores de un estudio
   en un periodo. Solo juegos base; las tablas 2 y 3 no cuentan lo reembolsado */
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

    IF @Fecha_Inicio > @Fecha_Fin
    BEGIN
        RAISERROR('Error: La fecha de inicio no puede ser posterior a la fecha de fin.', 16, 1);
        RETURN;
    END

    /* Tabla 1: KPIs */
    DECLARE @Ingreso_Bruto DECIMAL(12,2);
    DECLARE @Unidades_Vendidas INT;
    DECLARE @Total_Reembolsado DECIMAL(12,2);

    SELECT
        @Ingreso_Bruto = ISNULL(SUM(df.Precio_Venta_Historico), 0.00),
        @Unidades_Vendidas = COUNT(*)
    FROM Detalle_Factura df
    JOIN Factura f ON df.ID_Factura = f.ID_Factura
    JOIN Juego_Base jb ON df.ID_Producto = jb.ID_Producto
    WHERE jb.ID_Estudio_Dev = @ID_Empresa
      AND CAST(f.Fecha_Hora_Emision AS DATE) BETWEEN @Fecha_Inicio AND @Fecha_Fin;

    SELECT @Total_Reembolsado = ISNULL(SUM(r.Monto_Reembolsado), 0.00)
    FROM Reembolso r
    JOIN Juego_Base jb ON r.ID_Producto = jb.ID_Producto
    WHERE jb.ID_Estudio_Dev = @ID_Empresa
      AND CAST(r.Fecha_Reembolso AS DATE) BETWEEN @Fecha_Inicio AND @Fecha_Fin;

    SELECT
        e.Nombre AS Estudio,
        @Ingreso_Bruto AS Ingreso_Bruto,
        @Total_Reembolsado AS Total_Reembolsado,
        @Ingreso_Bruto - @Total_Reembolsado AS Ingreso_Neto,
        @Unidades_Vendidas AS Unidades_Vendidas
    FROM Empresa_Corporativa e
    WHERE e.ID_Empresa = @ID_Empresa;

    /* Tabla 2: 5 juegos más vendidos (r.ID_Factura IS NULL = línea no reembolsada) */
    SELECT TOP 5
        pd.Titulo,
        COUNT(df.ID_Factura) AS Unidades_Vendidas,
        SUM(df.Precio_Venta_Historico) AS Ingreso_Generado
    FROM Juego_Base jb
    JOIN Producto_Digital pd ON jb.ID_Producto = pd.ID_Producto
    JOIN Detalle_Factura df ON pd.ID_Producto = df.ID_Producto
    JOIN Factura f ON df.ID_Factura = f.ID_Factura
    LEFT JOIN Reembolso r ON df.ID_Factura = r.ID_Factura AND df.ID_Producto = r.ID_Producto
    WHERE jb.ID_Estudio_Dev = @ID_Empresa
      AND CAST(f.Fecha_Hora_Emision AS DATE) BETWEEN @Fecha_Inicio AND @Fecha_Fin
      AND r.ID_Factura IS NULL
    GROUP BY pd.Titulo
    ORDER BY Unidades_Vendidas DESC, Ingreso_Generado DESC;

    /* Tabla 3: 5 mejores compradores por gasto en juegos del estudio */
    SELECT TOP 5
        u.Nickname,
        u.Pais_Residencia,
        SUM(df.Precio_Venta_Historico) AS Gasto_Total
    FROM Factura f
    JOIN Usuario u ON f.ID_Usuario = u.ID_Usuario
    JOIN Detalle_Factura df ON f.ID_Factura = df.ID_Factura
    JOIN Juego_Base jb ON df.ID_Producto = jb.ID_Producto
    LEFT JOIN Reembolso r ON df.ID_Factura = r.ID_Factura AND df.ID_Producto = r.ID_Producto
    WHERE jb.ID_Estudio_Dev = @ID_Empresa
      AND CAST(f.Fecha_Hora_Emision AS DATE) BETWEEN @Fecha_Inicio AND @Fecha_Fin
      AND r.ID_Factura IS NULL
    GROUP BY u.Nickname, u.Pais_Residencia
    ORDER BY Gasto_Total DESC;
END;
GO

/* sp_publicar_producto_con_etiquetas: crea el producto, su subtabla (Juego_Base o DLC)
   y lo vincula a cada etiqueta de la lista, creando las que no existan */
CREATE OR ALTER PROCEDURE dbo.sp_publicar_producto_con_etiquetas
    /* Producto_Digital */
    @Titulo NVARCHAR(150),
    @Descripcion_Corta NVARCHAR(255),
    @Descripcion_Larga NVARCHAR(MAX),
    @Fecha_Lanzamiento DATE,
    @Tamano_GB DECIMAL(6,2),
    @Clasificacion_Edad NVARCHAR(5),
    @Precio_Base_Actual DECIMAL(10,2),
    @Tipo_Producto NVARCHAR(20),
    @Metacritic_Score INT,
    /* Solo Juego_Base */
    @ID_Estudio_Dev INT = NULL,
    @ID_Publisher INT = NULL,
    @Motor_Grafico NVARCHAR(100) = NULL,
    @Tiene_Compras_InGame BIT = 0,
    @Soporta_Cloud_Saves BIT = 1,
    /* Solo DLC */
    @ID_Juego_Base INT = NULL,
    @Tipo_Contenido NVARCHAR(20) = NULL,
    @Subtipo_Jugable NVARCHAR(20) = NULL,
    /* Etiquetas separadas por comas */
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

        /* Etiquetas: el cursor recorre la lista una a una, sin espacios ni repetidas */
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
                /* Se reinicia porque un SELECT sin filas no cambia la variable */
                SET @ID_Etiqueta = NULL;

                SELECT @ID_Etiqueta = ID_Etiqueta
                FROM Etiqueta_Comunidad
                WHERE Nombre_Etiqueta = @TagActual;

                IF @ID_Etiqueta IS NULL
                BEGIN
                    INSERT INTO Etiqueta_Comunidad (Nombre_Etiqueta) VALUES (@TagActual);
                    SET @ID_Etiqueta = SCOPE_IDENTITY();
                END

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

/* sp_procesar_reembolso: reembolsa una línea de factura si la compra tiene menos de 14 días
   y se jugó menos de 2 horas. El trigger de reembolso revoca el acceso */
CREATE OR ALTER PROCEDURE dbo.sp_procesar_reembolso
    @ID_Factura INT,
    @ID_Producto INT,
    @Motivo NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Detalle_Factura WHERE ID_Factura = @ID_Factura AND ID_Producto = @ID_Producto)
    BEGIN
        RAISERROR('Error: El producto especificado no forma parte de la factura indicada.', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM Reembolso WHERE ID_Factura = @ID_Factura AND ID_Producto = @ID_Producto)
    BEGIN
        RAISERROR('Error: Este producto ya ha sido reembolsado anteriormente.', 16, 1);
        RETURN;
    END

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

    DECLARE @Ahora DATETIME2 = GETDATE();

    /* Vence a los 14 días exactos desde la hora de compra */
    IF DATEADD(DAY, 14, @Fecha_Compra) <= @Ahora
    BEGIN
        RAISERROR('Error: La compra supera el periodo de garantía de 14 días para reembolsos.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM Biblioteca WHERE ID_Usuario = @ID_Usuario AND ID_Producto = @ID_Producto)
    BEGIN
        RAISERROR('Error: El producto no está en la biblioteca del usuario.', 16, 1);
        RETURN;
    END

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

        INSERT INTO Reembolso (ID_Factura, ID_Producto, Fecha_Reembolso, Monto_Reembolsado, Motivo)
        VALUES (@ID_Factura, @ID_Producto, @Ahora, @Precio_Pagado, @Motivo);

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

/* sp_desbloquear_logro: registra el logro si pertenece al juego, el usuario tiene el juego
   en su biblioteca y no lo había desbloqueado antes */
CREATE OR ALTER PROCEDURE dbo.sp_desbloquear_logro
    @ID_Usuario INT,
    @ID_Juego_Base INT,
    @ID_Logro INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Logro WHERE ID_Juego_Base = @ID_Juego_Base AND ID_Logro = @ID_Logro)
    BEGIN
        RAISERROR('Error: El logro no existe o no pertenece al juego base especificado.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM Biblioteca WHERE ID_Usuario = @ID_Usuario AND ID_Producto = @ID_Juego_Base)
    BEGIN
        RAISERROR('Error: El usuario no posee este juego en su biblioteca.', 16, 1);
        RETURN;
    END

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
