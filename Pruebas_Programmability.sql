/* Pruebas_Programmability.sql: prueba cada función, trigger y procedimiento de Programmability.sql
   con casos que deben funcionar y casos que deben fallar.

   Requisitos: DDL.sql, Inserts.sql y Programmability.sql ejecutados en ese orden, y el mismo día
   que Inserts.sql. Las pruebas 37 y 45 dependen de las fechas que Inserts.sql ajusta a GETDATE().

   Cada prueba va en su propio lote y dentro de una transacción que se deshace al final, así que la
   base queda como estaba y el script se puede repetir. Lo único que no se deshace son los valores
   IDENTITY consumidos (Factura, Producto_Digital, Etiqueta_Comunidad, Reembolso), que dejan huecos.

   Las dos últimas tablas de la pestaña Results son el resumen. Todo debe salir OK, salvo la prueba
   37, que se compara a mano con el comentario que la acompaña. Las tablas intermedias son la salida
   normal de los procedimientos. Los errores esperados no salen en Messages porque los captura
   TRY/CATCH. Si en las pruebas 32 o 44 aparece el aviso 266 (Transaction count after EXECUTE...),
   es esperable: el procedimiento deshace también la transacción abierta por la prueba. */
USE ConeSTeamDB;
GO

SET NOCOUNT ON;

DROP TABLE IF EXISTS #Resultados;
CREATE TABLE #Resultados (
    N INT PRIMARY KEY,
    Objeto NVARCHAR(60),
    Prueba NVARCHAR(200),
    Esperado NVARCHAR(400),
    Obtenido NVARCHAR(4000)
);
GO

/* PARTE 1: FUNCIONES */

/* 1 a 17. Las funciones no modifican datos, así que no necesitan transacción */
DECLARE @ini DATE, @fin DATE;

/* Summer Sale 2026 de Elden Ring (ID 14): 40% sobre 59.99. Se busca por nombre porque
   Inserts.sql desplaza las fechas */
SELECT @ini = Fecha_Inicio, @fin = Fecha_Fin
FROM Historial_Descuento
WHERE ID_Producto = 14 AND Nombre_Evento = 'Summer Sale 2026';

INSERT INTO #Resultados VALUES
  (1,  'fn_calcular_impuesto', N'16% de 100.00',                      N'16.00', CAST(dbo.fn_calcular_impuesto(100.00) AS NVARCHAR(50))),
  (2,  'fn_calcular_impuesto', N'16% de 59.99 (9.5984 redondea)',     N'9.60',  CAST(dbo.fn_calcular_impuesto(59.99) AS NVARCHAR(50))),
  (3,  'fn_calcular_impuesto', N'Monto 0',                            N'0.00',  CAST(dbo.fn_calcular_impuesto(0.00) AS NVARCHAR(50))),
  (4,  'fn_calcular_impuesto', N'Monto negativo',                     N'0.00',  CAST(dbo.fn_calcular_impuesto(-5.00) AS NVARCHAR(50))),
  (5,  'fn_calcular_impuesto', N'Monto NULL',                         N'0.00',  CAST(dbo.fn_calcular_impuesto(NULL) AS NVARCHAR(50))),
  (6,  'fn_precio_con_descuento', N'Elden Ring, primer día de rebaja (40%)', N'35.99', CAST(dbo.fn_precio_con_descuento(14, @ini) AS NVARCHAR(50))),
  (7,  'fn_precio_con_descuento', N'Elden Ring, último día de rebaja',       N'35.99', CAST(dbo.fn_precio_con_descuento(14, @fin) AS NVARCHAR(50))),
  (8,  'fn_precio_con_descuento', N'Elden Ring, día anterior sin rebaja',    N'59.99', CAST(dbo.fn_precio_con_descuento(14, DATEADD(DAY, -1, @ini)) AS NVARCHAR(50))),
  (9,  'fn_precio_con_descuento', N'Producto inexistente',                   N'0.00',  CAST(dbo.fn_precio_con_descuento(9999, GETDATE()) AS NVARCHAR(50))),
  (10, 'fn_clasificar_ingreso', N'10000.01',                          N'AAA',         dbo.fn_clasificar_ingreso(10000.01)),
  (11, 'fn_clasificar_ingreso', N'10000.00 (límite superior)',        N'Consolidado', dbo.fn_clasificar_ingreso(10000.00)),
  (12, 'fn_clasificar_ingreso', N'2000.00 (límite inferior)',         N'Consolidado', dbo.fn_clasificar_ingreso(2000.00)),
  (13, 'fn_clasificar_ingreso', N'1999.99',                           N'Indie',       dbo.fn_clasificar_ingreso(1999.99)),
  /* Elden Ring: 40 reseñas con media 9.28, Metacritic 96, 62 en biblioteca.
     9.28*7 + 96*0.2 + 62*0.05 = 64.96 + 19.20 + 3.10 */
  (14, 'fn_calcular_reputacion', N'Elden Ring (ID 14)',               N'87.26', CAST(dbo.fn_calcular_reputacion(14) AS NVARCHAR(50))),
  /* Shadow of the Erdtree: media 8.83, Metacritic NULL (cuenta 0), 25 en biblioteca.
     8.83*7 + 0 + 25*0.05 = 61.81 + 1.25 */
  (15, 'fn_calcular_reputacion', N'DLC sin Metacritic (ID 222)',      N'63.06', CAST(dbo.fn_calcular_reputacion(222) AS NVARCHAR(50))),
  (16, 'fn_calcular_horas_totales_usuario', N'Usuario 22',               N'414.00', CAST(dbo.fn_calcular_horas_totales_usuario(22) AS NVARCHAR(50))),
  (17, 'fn_calcular_horas_totales_usuario', N'Usuario 8, sin biblioteca', N'0.00',  CAST(dbo.fn_calcular_horas_totales_usuario(8) AS NVARCHAR(50)));
GO

/* PARTE 2: TRIGGERS */

/* 18. Trigger 1: subida del 16.7% (59.99 a 69.99), se permite */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    UPDATE Producto_Digital SET Precio_Base_Actual = 69.99 WHERE ID_Producto = 14;
    SELECT @obt = 'Precio=' + CAST(Precio_Base_Actual AS NVARCHAR(20)) FROM Producto_Digital WHERE ID_Producto = 14;
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (18, 'trg_auditoria_precios', N'Subida del 16.7% (59.99 a 69.99)', N'Precio=69.99', @obt);
GO

/* 19. Trigger 1: subida del 66.7% (59.99 a 99.99), se cancela */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    UPDATE Producto_Digital SET Precio_Base_Actual = 99.99 WHERE ID_Producto = 14;
    SET @obt = 'Precio cambiado';
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (19, 'trg_auditoria_precios', N'Subida del 66.7% (59.99 a 99.99)',
    N'ERROR: Operación cancelada: El cambio de precio supera el 50% permitido respecto al valor anterior.', @obt);
GO

/* 20. Trigger 1: bajada del 66.7% (59.99 a 19.99), se cancela */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    UPDATE Producto_Digital SET Precio_Base_Actual = 19.99 WHERE ID_Producto = 14;
    SET @obt = 'Precio cambiado';
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (20, 'trg_auditoria_precios', N'Bajada del 66.7% (59.99 a 19.99)',
    N'ERROR: Operación cancelada: El cambio de precio supera el 50% permitido respecto al valor anterior.', @obt);
GO

/* 21. Trigger 1: precio anterior 0 (DLC gratuito 222 a 9.99), se permite */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    UPDATE Producto_Digital SET Precio_Base_Actual = 9.99 WHERE ID_Producto = 222;
    SELECT @obt = 'Precio=' + CAST(Precio_Base_Actual AS NVARCHAR(20)) FROM Producto_Digital WHERE ID_Producto = 222;
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (21, 'trg_auditoria_precios', N'Precio anterior 0 (0.00 a 9.99)', N'Precio=9.99', @obt);
GO

/* 22. Trigger 2: el usuario 2, menor, compra Elden Ring (M) en su factura 4, se cancela */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    INSERT INTO Detalle_Factura (ID_Factura, ID_Producto, Precio_Venta_Historico, Descuento_Aplicado_Pct)
    VALUES (4, 14, 59.99, 0.00);
    SET @obt = 'Linea insertada';
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (22, 'trg_proteccion_menores', N'Menor compra un juego M', N'ERROR: Contenido restringido por edad', @obt);
GO

/* 23. Triggers 2 y 3: el usuario 103, adulto, compra DOOM Eternal (M) en su factura 523.
   Se permite y el juego entra en su biblioteca con 0 horas */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    INSERT INTO Detalle_Factura (ID_Factura, ID_Producto, Precio_Venta_Historico, Descuento_Aplicado_Pct)
    VALUES (523, 29, 39.99, 0.00);
    SELECT @obt = 'Horas=' + CAST(Horas_Jugadas AS NVARCHAR(20)) FROM Biblioteca WHERE ID_Usuario = 103 AND ID_Producto = 29;
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (23, 'trg_poblado_biblioteca', N'Adulto compra un juego M: entra en Biblioteca', N'Horas=0.00', @obt);
GO

/* 24. Trigger 3: el usuario 103 vuelve a comprar Elden Ring, que ya tiene.
   No se duplica en su biblioteca, que sigue con 12 productos */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    INSERT INTO Detalle_Factura (ID_Factura, ID_Producto, Precio_Venta_Historico, Descuento_Aplicado_Pct)
    VALUES (523, 14, 59.99, 0.00);
    SELECT @obt = 'Filas=' + CAST(COUNT(*) AS NVARCHAR(10)) FROM Biblioteca WHERE ID_Usuario = 103;
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (24, 'trg_poblado_biblioteca', N'Producto ya poseído: no se duplica', N'Filas=12', @obt);
GO

/* 25. Trigger 4: reembolso directo de Forza Horizon 5 (factura 523, usuario 103).
   El juego sale de su biblioteca */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    INSERT INTO Reembolso (ID_Factura, ID_Producto, Fecha_Reembolso, Monto_Reembolsado, Motivo)
    VALUES (523, 68, SYSDATETIME(), 59.99, N'Prueba del trigger 4');
    SELECT @obt = 'EnBiblioteca=' + CAST(COUNT(*) AS NVARCHAR(10)) FROM Biblioteca WHERE ID_Usuario = 103 AND ID_Producto = 68;
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (25, 'trg_reembolso_revocacion', N'Reembolso quita el producto de Biblioteca', N'EnBiblioteca=0', @obt);
GO

/* 26. Trigger 5: el usuario 82 añade al carrito Civilization VI, que ya tiene, se cancela */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    INSERT INTO Carrito (ID_Usuario, ID_Producto, Fecha_Agregado) VALUES (82, 24, CAST(GETDATE() AS DATE));
    SET @obt = 'Agregado al carrito';
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (26, 'trg_validaciones_carrito', N'Producto ya poseído',
    N'ERROR: Operación cancelada: El usuario ya posee este producto en su biblioteca.', @obt);
GO

/* 27. Trigger 5: el usuario 34 añade el DLC 211 sin tener Los Sims 4 (ID 1), se cancela */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    INSERT INTO Carrito (ID_Usuario, ID_Producto, Fecha_Agregado) VALUES (34, 211, CAST(GETDATE() AS DATE));
    SET @obt = 'Agregado al carrito';
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (27, 'trg_validaciones_carrito', N'DLC sin su juego base',
    N'ERROR: Operación cancelada: Para comprar un DLC debe poseer el juego base en su biblioteca o incluirlo en el carrito.', @obt);
GO

/* 28. Trigger 5: el usuario 1 añade el DLC 222 y tiene Elden Ring en su biblioteca, se permite */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    INSERT INTO Carrito (ID_Usuario, ID_Producto, Fecha_Agregado) VALUES (1, 222, CAST(GETDATE() AS DATE));
    SELECT @obt = 'Carrito=' + CAST(COUNT(*) AS NVARCHAR(10)) FROM Carrito WHERE ID_Usuario = 1 AND ID_Producto = 222;
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (28, 'trg_validaciones_carrito', N'DLC con el juego base en Biblioteca', N'Carrito=1', @obt);
GO

/* 29. Trigger 5: el usuario 34 añade Los Sims 4 y su DLC 211 en el mismo INSERT, se permite */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    INSERT INTO Carrito (ID_Usuario, ID_Producto, Fecha_Agregado) VALUES
      (34, 1,   CAST(GETDATE() AS DATE)),
      (34, 211, CAST(GETDATE() AS DATE));
    SELECT @obt = 'Carrito=' + CAST(COUNT(*) AS NVARCHAR(10)) FROM Carrito WHERE ID_Usuario = 34 AND ID_Producto IN (1, 211);
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (29, 'trg_validaciones_carrito', N'DLC y juego base en el mismo carrito', N'Carrito=2', @obt);
GO

/* PARTE 3: PROCEDIMIENTOS */

/* 30. sp_realizar_compra: el carrito del usuario 16 tiene Resident Evil 5 (19.99) y su DLC
   gratuito 267, sin rebajas vigentes. IVA = 16% de 19.99 = 3.20. Los dos entran en su
   biblioteca por el Trigger 3 y el carrito queda vacío */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.sp_realizar_compra @ID_Usuario = 16, @ID_Metodo_Pago = 1;
    SELECT TOP 1 @obt = 'Sub=' + CAST(f.Sub_Total AS NVARCHAR(20))
                      + ' Desc=' + CAST(f.Monto_Descuento AS NVARCHAR(20))
                      + ' IVA=' + CAST(f.Monto_Impuesto AS NVARCHAR(20))
                      + ' Total=' + CAST(f.Total_Pagado AS NVARCHAR(20))
                      + ' Lineas=' + CAST((SELECT COUNT(*) FROM Detalle_Factura d WHERE d.ID_Factura = f.ID_Factura) AS NVARCHAR(10))
    FROM Factura f
    WHERE f.ID_Usuario = 16
    ORDER BY f.ID_Factura DESC;
    SET @obt += ' Bib=' + CAST((SELECT COUNT(*) FROM Biblioteca WHERE ID_Usuario = 16 AND ID_Producto IN (69, 267) AND Horas_Jugadas = 0) AS NVARCHAR(10))
              + ' Carrito=' + CAST((SELECT COUNT(*) FROM Carrito WHERE ID_Usuario = 16) AS NVARCHAR(10));
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (30, 'sp_realizar_compra', N'Juego base y su DLC',
    N'Sub=19.99 Desc=0.00 IVA=3.20 Total=23.19 Lineas=2 Bib=2 Carrito=0', @obt);
GO

/* 31. sp_realizar_compra: el usuario 78 es menor, pero su carrito solo tiene juegos E
   (Super Mario Bros. Wonder 59.99 y SimCity 39.99). IVA = 16% de 99.98 = 16.00 */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.sp_realizar_compra @ID_Usuario = 78, @ID_Metodo_Pago = 2;
    SELECT TOP 1 @obt = 'Sub=' + CAST(f.Sub_Total AS NVARCHAR(20))
                      + ' Desc=' + CAST(f.Monto_Descuento AS NVARCHAR(20))
                      + ' IVA=' + CAST(f.Monto_Impuesto AS NVARCHAR(20))
                      + ' Total=' + CAST(f.Total_Pagado AS NVARCHAR(20))
                      + ' Lineas=' + CAST((SELECT COUNT(*) FROM Detalle_Factura d WHERE d.ID_Factura = f.ID_Factura) AS NVARCHAR(10))
    FROM Factura f
    WHERE f.ID_Usuario = 78
    ORDER BY f.ID_Factura DESC;
    SET @obt += ' Bib=' + CAST((SELECT COUNT(*) FROM Biblioteca WHERE ID_Usuario = 78) AS NVARCHAR(10))
              + ' Carrito=' + CAST((SELECT COUNT(*) FROM Carrito WHERE ID_Usuario = 78) AS NVARCHAR(10));
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (31, 'sp_realizar_compra', N'Menor con juegos E: se permite',
    N'Sub=99.98 Desc=0.00 IVA=16.00 Total=115.98 Lineas=2 Bib=2 Carrito=0', @obt);
GO

/* 32. sp_realizar_compra: el usuario 177 es menor y lleva DOOM Eternal (M). El Trigger 2 cancela
   la línea y el procedimiento deshace la factura entera. Se comprueba antes del ROLLBACK de la
   prueba que el propio procedimiento dejó el carrito intacto y no creó factura */
DECLARE @obt NVARCHAR(4000);
DECLARE @facturas_antes INT = (SELECT COUNT(*) FROM Factura WHERE ID_Usuario = 177);
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.sp_realizar_compra @ID_Usuario = 177, @ID_Metodo_Pago = 1;
    SET @obt = 'Compra realizada';
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE()
             + ' | Carrito=' + CAST((SELECT COUNT(*) FROM Carrito WHERE ID_Usuario = 177) AS NVARCHAR(10))
             + ' | Facturas+' + CAST((SELECT COUNT(*) FROM Factura WHERE ID_Usuario = 177) - @facturas_antes AS NVARCHAR(10));
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (32, 'sp_realizar_compra', N'Menor con un juego M: se deshace todo',
    N'ERROR: Contenido restringido por edad | Carrito=2 | Facturas+0', @obt);
GO

/* 33. sp_realizar_compra: el usuario 8 no tiene carrito */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.sp_realizar_compra @ID_Usuario = 8, @ID_Metodo_Pago = 1;
    SET @obt = 'Compra realizada';
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (33, 'sp_realizar_compra', N'Carrito vacío', N'ERROR: Error: El carrito del usuario está vacío.', @obt);
GO

/* 34. sp_realizar_compra: usuario inexistente */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.sp_realizar_compra @ID_Usuario = 9999, @ID_Metodo_Pago = 1;
    SET @obt = 'Compra realizada';
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (34, 'sp_realizar_compra', N'Usuario inexistente', N'ERROR: Error: El usuario especificado no existe.', @obt);
GO

/* 35. sp_realizar_compra: método de pago inexistente */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.sp_realizar_compra @ID_Usuario = 16, @ID_Metodo_Pago = 99;
    SET @obt = 'Compra realizada';
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (35, 'sp_realizar_compra', N'Método de pago inexistente', N'ERROR: Error: El método de pago especificado no existe.', @obt);
GO

/* 36. sp_realizar_compra: el Trigger 5 impide que esto pase por el carrito, así que se mete
   Spore directamente en la biblioteca del usuario 3, que la tiene en el carrito */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    INSERT INTO Biblioteca (ID_Usuario, ID_Producto, Horas_Jugadas, Fecha_Ultima_Sesion) VALUES (3, 84, 0.00, NULL);
    EXEC dbo.sp_realizar_compra @ID_Usuario = 3, @ID_Metodo_Pago = 1;
    SET @obt = 'Compra realizada';
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (36, 'sp_realizar_compra', N'Carrito con un producto ya poseído',
    N'ERROR: Error: El usuario ya posee uno o más productos del carrito en su biblioteca.', @obt);
GO

/* 37. sp_dashboard_estudio: FromSoftware (ID 31) en el último año. Se revisa a mano en las tres
   tablas que devuelve:
   Tabla 1: FromSoftware | Ingreso_Bruto 2415.55 | Total_Reembolsado 79.98 | Ingreso_Neto 2335.57 | Unidades_Vendidas 46
   Tabla 2: Elden Ring 28 / 1679.72; Dark Souls III 7 / 255.94; Dark Souls II: Scholar of the First Sin 3 / 119.97;
            Dark Souls: Remastered y Bloodborne 2 / 79.98 (empatados, en cualquier orden)
   Tabla 3: Velvet.Fox75 (Estados Unidos) 115.98; TurboSparrow (España), FeralRocket87 (Chile) y
            GlitchMoth (Venezuela) 99.98 (empatados); quinto, cualquiera de los empatados a 59.99 */
DECLARE @hoy DATE = CAST(GETDATE() AS DATE);
DECLARE @hace_un_anio DATE = DATEADD(YEAR, -1, @hoy);
EXEC dbo.sp_dashboard_estudio @ID_Empresa = 31, @Fecha_Inicio = @hace_un_anio, @Fecha_Fin = @hoy;
INSERT INTO #Resultados VALUES (37, 'sp_dashboard_estudio', N'FromSoftware, último año',
    N'Comparar con el comentario de la prueba 37', N'Ver las tres tablas devueltas');
GO

/* 38. sp_dashboard_estudio: empresa inexistente */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    EXEC dbo.sp_dashboard_estudio @ID_Empresa = 9999, @Fecha_Inicio = '2025-01-01', @Fecha_Fin = '2025-12-31';
    SET @obt = 'Dashboard devuelto';
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
END CATCH
INSERT INTO #Resultados VALUES (38, 'sp_dashboard_estudio', N'Empresa inexistente', N'ERROR: Error: La empresa especificada no existe.', @obt);
GO

/* 39. sp_dashboard_estudio: fecha de inicio posterior a la de fin */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    EXEC dbo.sp_dashboard_estudio @ID_Empresa = 31, @Fecha_Inicio = '2026-12-31', @Fecha_Fin = '2026-01-01';
    SET @obt = 'Dashboard devuelto';
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
END CATCH
INSERT INTO #Resultados VALUES (39, 'sp_dashboard_estudio', N'Fechas invertidas',
    N'ERROR: Error: La fecha de inicio no puede ser posterior a la fecha de fin.', @obt);
GO

/* 40. sp_publicar_producto_con_etiquetas: juego base con 'RPG' y 'Souls-like' (ya existen),
   'Etiqueta de prueba' (nueva) y 'RPG' repetida con espacios. Quedan 3 etiquetas y 1 nueva */
DECLARE @obt NVARCHAR(4000);
DECLARE @etiquetas_antes INT = (SELECT COUNT(*) FROM Etiqueta_Comunidad);
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.sp_publicar_producto_con_etiquetas
        @Titulo = N'Juego de prueba', @Descripcion_Corta = N'Prueba.', @Descripcion_Larga = N'Producto creado por Pruebas_Programmability.sql.',
        @Fecha_Lanzamiento = '2026-10-01', @Tamano_GB = 10.50, @Clasificacion_Edad = 'T', @Precio_Base_Actual = 29.99,
        @Tipo_Producto = 'Juego_Base', @Metacritic_Score = NULL,
        @ID_Estudio_Dev = 31, @ID_Publisher = 31, @Motor_Grafico = N'Unreal Engine 5',
        @Lista_Etiquetas = N'RPG, Souls-like, Etiqueta de prueba, RPG';
    DECLARE @id INT = (SELECT MAX(ID_Producto) FROM Producto_Digital WHERE Titulo = N'Juego de prueba');
    SET @obt = 'JuegoBase=' + CAST((SELECT COUNT(*) FROM Juego_Base WHERE ID_Producto = @id) AS NVARCHAR(10))
             + ' Etiquetas=' + CAST((SELECT COUNT(*) FROM Producto_Etiqueta WHERE ID_Producto = @id) AS NVARCHAR(10))
             + ' Nuevas=' + CAST((SELECT COUNT(*) FROM Etiqueta_Comunidad) - @etiquetas_antes AS NVARCHAR(10));
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (40, 'sp_publicar_producto_con_etiquetas', N'Juego base con etiquetas nuevas y repetidas',
    N'JuegoBase=1 Etiquetas=3 Nuevas=1', @obt);
GO

/* 41. sp_publicar_producto_con_etiquetas: DLC jugable de Elden Ring con una etiqueta existente */
DECLARE @obt NVARCHAR(4000);
DECLARE @etiquetas_antes INT = (SELECT COUNT(*) FROM Etiqueta_Comunidad);
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.sp_publicar_producto_con_etiquetas
        @Titulo = N'DLC de prueba', @Descripcion_Corta = N'Prueba.', @Descripcion_Larga = N'Producto creado por Pruebas_Programmability.sql.',
        @Fecha_Lanzamiento = '2026-10-01', @Tamano_GB = 2.00, @Clasificacion_Edad = 'M', @Precio_Base_Actual = 9.99,
        @Tipo_Producto = 'DLC', @Metacritic_Score = NULL,
        @ID_Juego_Base = 14, @Tipo_Contenido = 'Jugable', @Subtipo_Jugable = 'Mapa',
        @Lista_Etiquetas = N'Souls-like';
    DECLARE @id INT = (SELECT MAX(ID_Producto) FROM Producto_Digital WHERE Titulo = N'DLC de prueba');
    SET @obt = 'DLC=' + CAST((SELECT COUNT(*) FROM DLC WHERE ID_Producto = @id AND ID_Juego_Base = 14) AS NVARCHAR(10))
             + ' Etiquetas=' + CAST((SELECT COUNT(*) FROM Producto_Etiqueta WHERE ID_Producto = @id) AS NVARCHAR(10))
             + ' Nuevas=' + CAST((SELECT COUNT(*) FROM Etiqueta_Comunidad) - @etiquetas_antes AS NVARCHAR(10));
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (41, 'sp_publicar_producto_con_etiquetas', N'DLC con etiqueta existente',
    N'DLC=1 Etiquetas=1 Nuevas=0', @obt);
GO

/* 42. sp_publicar_producto_con_etiquetas: tipo de producto inválido */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.sp_publicar_producto_con_etiquetas
        @Titulo = N'Mod de prueba', @Descripcion_Corta = N'Prueba.', @Descripcion_Larga = N'Prueba.',
        @Fecha_Lanzamiento = '2026-10-01', @Tamano_GB = 1.00, @Clasificacion_Edad = 'E', @Precio_Base_Actual = 0.00,
        @Tipo_Producto = 'Mod', @Metacritic_Score = NULL;
    SET @obt = 'Producto creado';
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (42, 'sp_publicar_producto_con_etiquetas', N'Tipo de producto inválido',
    N'ERROR: Error: Tipo_Producto debe ser "Juego_Base" o "DLC".', @obt);
GO

/* 43. sp_publicar_producto_con_etiquetas: DLC de un juego base inexistente */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.sp_publicar_producto_con_etiquetas
        @Titulo = N'DLC huérfano', @Descripcion_Corta = N'Prueba.', @Descripcion_Larga = N'Prueba.',
        @Fecha_Lanzamiento = '2026-10-01', @Tamano_GB = 1.00, @Clasificacion_Edad = 'E', @Precio_Base_Actual = 4.99,
        @Tipo_Producto = 'DLC', @Metacritic_Score = NULL,
        @ID_Juego_Base = 9999, @Tipo_Contenido = 'Arte';
    SET @obt = 'Producto creado';
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (43, 'sp_publicar_producto_con_etiquetas', N'DLC sin juego base existente',
    N'ERROR: Error: Todo DLC debe estar vinculado a un Juego_Base existente.', @obt);
GO

/* 44. sp_publicar_producto_con_etiquetas: atomicidad. El estudio 9999 no existe, así que el
   INSERT en Juego_Base falla después de haber insertado en Producto_Digital. El procedimiento
   debe deshacer también ese primer INSERT. Se comprueba antes del ROLLBACK de la prueba.
   El mensaje de la FK depende del idioma del servidor, por eso solo se busca su nombre */
DECLARE @obt NVARCHAR(4000);
DECLARE @productos_antes INT = (SELECT COUNT(*) FROM Producto_Digital);
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.sp_publicar_producto_con_etiquetas
        @Titulo = N'Juego atómico', @Descripcion_Corta = N'Prueba.', @Descripcion_Larga = N'Prueba.',
        @Fecha_Lanzamiento = '2026-10-01', @Tamano_GB = 1.00, @Clasificacion_Edad = 'E', @Precio_Base_Actual = 9.99,
        @Tipo_Producto = 'Juego_Base', @Metacritic_Score = NULL,
        @ID_Estudio_Dev = 9999, @ID_Publisher = 31, @Motor_Grafico = N'Unity',
        @Lista_Etiquetas = N'RPG';
    SET @obt = 'Producto creado';
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = CASE WHEN ERROR_MESSAGE() LIKE '%FK_JuegoBase_Estudio%' THEN 'ERROR FK_JuegoBase_Estudio'
                    ELSE 'ERROR: ' + ERROR_MESSAGE() END
             + ' | Productos+' + CAST((SELECT COUNT(*) FROM Producto_Digital) - @productos_antes AS NVARCHAR(10));
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (44, 'sp_publicar_producto_con_etiquetas', N'Fallo a mitad: no queda nada insertado',
    N'ERROR FK_JuegoBase_Estudio | Productos+0', @obt);
GO

/* 45. sp_procesar_reembolso: Forza Horizon 5 (factura 523, usuario 103), comprado hoy y con
   0 horas. Se devuelve lo pagado y el Trigger 4 lo quita de la biblioteca */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.sp_procesar_reembolso @ID_Factura = 523, @ID_Producto = 68, @Motivo = N'Prueba de reembolso';
    SELECT @obt = 'Monto=' + CAST(Monto_Reembolsado AS NVARCHAR(20)) FROM Reembolso WHERE ID_Factura = 523 AND ID_Producto = 68;
    SET @obt += ' EnBiblioteca=' + CAST((SELECT COUNT(*) FROM Biblioteca WHERE ID_Usuario = 103 AND ID_Producto = 68) AS NVARCHAR(10));
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (45, 'sp_procesar_reembolso', N'Compra reciente sin jugar', N'Monto=59.99 EnBiblioteca=0', @obt);
GO

/* 46. sp_procesar_reembolso: el producto 1 no está en la factura 523 */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.sp_procesar_reembolso @ID_Factura = 523, @ID_Producto = 1, @Motivo = N'Prueba';
    SET @obt = 'Reembolso hecho';
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (46, 'sp_procesar_reembolso', N'Producto fuera de la factura',
    N'ERROR: Error: El producto especificado no forma parte de la factura indicada.', @obt);
GO

/* 47. sp_procesar_reembolso: la línea (86, 192) ya está reembolsada en los Inserts */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.sp_procesar_reembolso @ID_Factura = 86, @ID_Producto = 192, @Motivo = N'Prueba';
    SET @obt = 'Reembolso hecho';
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (47, 'sp_procesar_reembolso', N'Línea ya reembolsada',
    N'ERROR: Error: Este producto ya ha sido reembolsado anteriormente.', @obt);
GO

/* 48. sp_procesar_reembolso: la factura 1 tiene más de un año */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.sp_procesar_reembolso @ID_Factura = 1, @ID_Producto = 131, @Motivo = N'Prueba';
    SET @obt = 'Reembolso hecho';
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (48, 'sp_procesar_reembolso', N'Compra de hace más de 14 días',
    N'ERROR: Error: La compra supera el periodo de garantía de 14 días para reembolsos.', @obt);
GO

/* 49. sp_procesar_reembolso: compra de hoy (factura 522, usuario 82) con exactamente 2 horas,
   que ya no admite reembolso. Las horas se ponen a mano dentro de la transacción */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    UPDATE Biblioteca SET Horas_Jugadas = 2.00 WHERE ID_Usuario = 82 AND ID_Producto = 24;
    EXEC dbo.sp_procesar_reembolso @ID_Factura = 522, @ID_Producto = 24, @Motivo = N'Prueba';
    SET @obt = 'Reembolso hecho';
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (49, 'sp_procesar_reembolso', N'2 horas jugadas exactas',
    N'ERROR: Error: El usuario ha jugado 2 horas o más a este título, no aplica reembolso.', @obt);
GO

/* 50. sp_desbloquear_logro: el usuario 1 tiene Overcooked (ID 12) y no ha desbloqueado el logro 1 */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.sp_desbloquear_logro @ID_Usuario = 1, @ID_Juego_Base = 12, @ID_Logro = 1;
    SELECT @obt = 'Desbloqueos=' + CAST(COUNT(*) AS NVARCHAR(10))
    FROM Desbloqueo_Logro WHERE ID_Usuario = 1 AND ID_Juego_Base = 12 AND ID_Logro = 1;
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (50, 'sp_desbloquear_logro', N'Logro nuevo de un juego que posee', N'Desbloqueos=1', @obt);
GO

/* 51. sp_desbloquear_logro: Overcooked no tiene logro 99 */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.sp_desbloquear_logro @ID_Usuario = 1, @ID_Juego_Base = 12, @ID_Logro = 99;
    SET @obt = 'Logro desbloqueado';
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (51, 'sp_desbloquear_logro', N'Logro que no existe en ese juego',
    N'ERROR: Error: El logro no existe o no pertenece al juego base especificado.', @obt);
GO

/* 52. sp_desbloquear_logro: el usuario 2 no tiene Elden Ring */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.sp_desbloquear_logro @ID_Usuario = 2, @ID_Juego_Base = 14, @ID_Logro = 1;
    SET @obt = 'Logro desbloqueado';
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (52, 'sp_desbloquear_logro', N'Juego que no posee',
    N'ERROR: Error: El usuario no posee este juego en su biblioteca.', @obt);
GO

/* 53. sp_desbloquear_logro: el usuario 1 ya desbloqueó el logro 2 de Overcooked */
DECLARE @obt NVARCHAR(4000);
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.sp_desbloquear_logro @ID_Usuario = 1, @ID_Juego_Base = 12, @ID_Logro = 2;
    SET @obt = 'Logro desbloqueado';
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @obt = 'ERROR: ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT INTO #Resultados VALUES (53, 'sp_desbloquear_logro', N'Logro ya desbloqueado',
    N'ERROR: Error: El usuario ya ha desbloqueado este logro previamente.', @obt);
GO

/* RESUMEN. Una prueba que no aparece es un lote que falló sin llegar a registrarse:
   buscar su error en la pestaña Messages */
SELECT N, Objeto, Prueba, Esperado, ISNULL(Obtenido, '(sin valor)') AS Obtenido,
       CASE WHEN N = 37 THEN 'REVISAR'
            WHEN Obtenido = Esperado THEN 'OK'
            ELSE 'FALLA' END AS Resultado
FROM #Resultados
ORDER BY CASE WHEN N <> 37 AND (Obtenido IS NULL OR Obtenido <> Esperado) THEN 0 ELSE 1 END, N;

SELECT 53 AS Pruebas_Previstas,
       COUNT(*) AS Registradas,
       SUM(CASE WHEN N <> 37 AND Obtenido = Esperado THEN 1 ELSE 0 END) AS OK,
       SUM(CASE WHEN N <> 37 AND (Obtenido IS NULL OR Obtenido <> Esperado) THEN 1 ELSE 0 END) AS FALLA,
       STUFF((SELECT ', ' + CAST(v.N AS VARCHAR(3))
              FROM (SELECT TOP 53 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS N FROM sys.all_objects) v
              WHERE NOT EXISTS (SELECT 1 FROM #Resultados r WHERE r.N = v.N)
              FOR XML PATH('')), 1, 2, '') AS Sin_Registrar
FROM #Resultados;
GO
