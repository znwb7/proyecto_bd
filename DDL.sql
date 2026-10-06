/* DDL.sql: Creación de tablas y restricciones del modelo relacional
    Base de datos centralizada: ConeSTeamDB */

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'ConeSTeamDB')
BEGIN
    CREATE DATABASE ConeSTeamDB;
END
GO

USE ConeSTeamDB;
GO

-- Limpieza preventiva en orden inverso a sus dependencias
DROP TABLE IF EXISTS Reembolso;
DROP TABLE IF EXISTS Detalle_Factura;
DROP TABLE IF EXISTS Factura;
DROP TABLE IF EXISTS Metodo_Pago;
DROP TABLE IF EXISTS Suscripcion_Mod;
DROP TABLE IF EXISTS Resena;
DROP TABLE IF EraXISTS Carrito;
DROP TABLE IF EXISTS Lista_Deseos;
DROP TABLE IF EXISTS Biblioteca;
DROP TABLE IF EXISTS Desbloqueo_Logro;
DROP TABLE IF EXISTS Amistad_Usuario;
DROP TABLE IF EXISTS Usuario;
DROP TABLE IF EXISTS [Mod];
DROP TABLE IF EXISTS Producto_Etiqueta;
DROP TABLE IF EXISTS Etiqueta_Comunidad;
DROP TABLE IF EXISTS Soporte_Idioma;
DROP TABLE IF EXISTS Idioma;
DROP TABLE IF EXISTS Juego_Categoria;
DROP TABLE IF EXISTS Categoria_Oficial;
DROP TABLE IF EXISTS Logro;
DROP TABLE IF EXISTS Perfil_Requisito;
DROP TABLE IF EXISTS DLC;
DROP TABLE IF EXISTS Juego_Base;
DROP TABLE IF EXISTS Galeria_Multimedia;
DROP TABLE IF EXISTS Historial_Descuento;
DROP TABLE IF EXISTS Registro_Concurrencia;
DROP TABLE IF EXISTS Producto_Digital;
DROP TABLE IF EXISTS Empresa_Corporativa;
GO

-- 1. Empresa_Corporativa
CREATE TABLE Empresa_Corporativa (
    ID_Empresa INT IDENTITY(1,1) PRIMARY KEY,
    Nombre NVARCHAR(100) NOT NULL,
    Pais_Origen NVARCHAR(60) NOT NULL,
    Fecha_Fundacion DATE NOT NULL,
    ID_Empresa_Matriz INT NULL,
    CONSTRAINT UQ_Empresa_Nombre UNIQUE (Nombre),
    CONSTRAINT FK_Empresa_Matriz FOREIGN KEY (ID_Empresa_Matriz) REFERENCES Empresa_Corporativa(ID_Empresa),
    CONSTRAINT CK_Empresa_NoAutoMatriz CHECK (ID_Empresa_Matriz IS NULL OR ID_Empresa_Matriz <> ID_Empresa)
);
GO

-- 2. Producto_Digital
CREATE TABLE Producto_Digital (
    ID_Producto INT IDENTITY(1,1) PRIMARY KEY,
    Titulo NVARCHAR(150) NOT NULL,
    Descripcion_Corta NVARCHAR(500) NOT NULL,
    Descripcion_Larga NVARCHAR(MAX) NOT NULL,
    Fecha_Lanzamiento DATE NOT NULL,
    Tamano_GB DECIMAL(8,2) NOT NULL,
    Clasificacion_Edad VARCHAR(5) NOT NULL,
    Precio_Base_Actual DECIMAL(10,2) NOT NULL,
    Tipo_Producto VARCHAR(20) NOT NULL,
    Metacritic_Score INT NULL,
    CONSTRAINT CK_Producto_Precio CHECK (Precio_Base_Actual >= 0),
    CONSTRAINT CK_Producto_Tamano CHECK (Tamano_GB >= 0),
    CONSTRAINT CK_Producto_Tipo CHECK (Tipo_Producto IN ('Juego_Base', 'DLC')),
    CONSTRAINT CK_Producto_Clasificacion CHECK (Clasificacion_Edad IN ('E', 'T', 'M', 'AO')),
    CONSTRAINT CK_Producto_Metacritic CHECK (Metacritic_Score IS NULL OR (Metacritic_Score BETWEEN 0 AND 100))
);
GO

-- 3. Galeria_Multimedia
CREATE TABLE Galeria_Multimedia (
    ID_Producto INT NOT NULL,
    ID_Multimedia INT NOT NULL,
    URL_Archivo NVARCHAR(300) NOT NULL,
    Tipo_Archivo VARCHAR(10) NOT NULL,
    CONSTRAINT PK_Galeria_Multimedia PRIMARY KEY (ID_Producto, ID_Multimedia),
    CONSTRAINT FK_Galeria_Producto FOREIGN KEY (ID_Producto) REFERENCES Producto_Digital(ID_Producto),
    CONSTRAINT CK_Galeria_Tipo CHECK (Tipo_Archivo IN ('Foto', 'Video'))
);
GO

-- 4. Juego_Base
CREATE TABLE Juego_Base (
    ID_Producto INT PRIMARY KEY,
    ID_Estudio_Dev INT NOT NULL,
    ID_Publisher INT NOT NULL,
    Motor_Grafico NVARCHAR(100) NOT NULL,
    Tiene_Compras_InGame BIT NOT NULL,
    Soporta_Cloud_Saves BIT NOT NULL,
    CONSTRAINT FK_JuegoBase_Producto FOREIGN KEY (ID_Producto) REFERENCES Producto_Digital(ID_Producto),
    CONSTRAINT FK_JuegoBase_Estudio FOREIGN KEY (ID_Estudio_Dev) REFERENCES Empresa_Corporativa(ID_Empresa),
    CONSTRAINT FK_JuegoBase_Publisher FOREIGN KEY (ID_Publisher) REFERENCES Empresa_Corporativa(ID_Empresa)
);
GO

-- 5. DLC
CREATE TABLE DLC (
    ID_Producto INT PRIMARY KEY,
    ID_Juego_Base INT NOT NULL,
    Tipo_Contenido VARCHAR(20) NOT NULL,
    Subtipo_Jugable VARCHAR(20) NULL,
    CONSTRAINT FK_DLC_Producto FOREIGN KEY (ID_Producto) REFERENCES Producto_Digital(ID_Producto),
    CONSTRAINT FK_DLC_JuegoBase FOREIGN KEY (ID_Juego_Base) REFERENCES Juego_Base(ID_Producto),
    CONSTRAINT CK_DLC_Tipo_Contenido CHECK (Tipo_Contenido IN ('Jugable', 'Banda_Sonora', 'Arte')),
    CONSTRAINT CK_DLC_Subtipo_Jugable CHECK (Subtipo_Jugable IS NULL OR Subtipo_Jugable IN  ('Personaje', 'Mapa', 'Modo_Juego', 'Cosmetico')),
    CONSTRAINT CK_DLC_Regla_Subtipo CHECK (
        (Tipo_Contenido = 'Jugable' AND Subtipo_Jugable IS NOT NULL) OR
        (Tipo_Contenido <> 'Jugable' AND Subtipo_Jugable IS NULL)
    )
);
GO

-- 6. Perfil_Requisito
CREATE TABLE Perfil_Requisito (
    ID_Producto INT NOT NULL,
    Tipo_Perfil VARCHAR(20) NOT NULL,
    Sistema_Operativo NVARCHAR(100) NOT NULL,
    Procesador NVARCHAR(150) NOT NULL,
    Memoria_RAM NVARCHAR(50) NOT NULL,
    Tarjeta_Grafica NVARCHAR(150) NOT NULL,
    CONSTRAINT PK_Perfil_Requisito PRIMARY KEY (ID_Producto, Tipo_Perfil),
    CONSTRAINT FK_Perfil_Producto FOREIGN KEY (ID_Producto) REFERENCES Producto_Digital(ID_Producto),
    CONSTRAINT CK_Perfil_Tipo CHECK (Tipo_Perfil IN ('Minimo', 'Recomendado'))
);
GO

-- 7. Logro
CREATE TABLE Logro (
    ID_Juego_Base INT NOT NULL,
    ID_Logro INT NOT NULL,
    Nombre_Logro NVARCHAR(100) NOT NULL,
    Descripcion_Logro NVARCHAR(300) NOT NULL,
    Es_Secreto BIT NOT NULL,
    CONSTRAINT PK_Logro PRIMARY KEY (ID_Juego_Base, ID_Logro),
    CONSTRAINT FK_Logro_JuegoBase FOREIGN KEY (ID_Juego_Base) REFERENCES Juego_Base(ID_Producto)
);
GO

-- 8. Categoria_Oficial
CREATE TABLE Categoria_Oficial (
    ID_Categoria INT IDENTITY(1,1) PRIMARY KEY,
    Nombre_Categoria NVARCHAR(100) NOT NULL,
    Descripcion_Categoria NVARCHAR(300) NOT NULL,
    CONSTRAINT UQ_Categoria_Nombre UNIQUE (Nombre_Categoria)
);
GO

-- 9. Juego_Categoria
CREATE TABLE Juego_Categoria (
    ID_Producto INT NOT NULL,
    ID_Categoria INT NOT NULL,
    CONSTRAINT PK_Juego_Categoria PRIMARY KEY (ID_Producto, ID_Categoria),
    CONSTRAINT FK_JuegoCat_Producto FOREIGN KEY (ID_Producto) REFERENCES Producto_Digital(ID_Producto),
    CONSTRAINT FK_JuegoCat_Categoria FOREIGN KEY (ID_Categoria) REFERENCES Categoria_Oficial(ID_Categoria)
);
GO

-- 10. Idioma
CREATE TABLE Idioma (
    ID_Idioma INT IDENTITY(1,1) PRIMARY KEY,
    Nombre_Idioma NVARCHAR(100) NOT NULL,
    CONSTRAINT UQ_Idioma_Nombre UNIQUE (Nombre_Idioma)
);
GO

-- 11. Soporte_Idioma
CREATE TABLE Soporte_Idioma (
    ID_Producto INT NOT NULL,
    ID_Idioma INT NOT NULL,
    Soporta_Interfaz BIT NOT NULL,
    Soporta_Audio BIT NOT NULL,
    Soporta_Subtitulos BIT NOT NULL,
    CONSTRAINT PK_Soporte_Idioma PRIMARY KEY (ID_Producto, ID_Idioma),
    CONSTRAINT FK_SoporteIdioma_Producto FOREIGN KEY (ID_Producto) REFERENCES Producto_Digital(ID_Producto),
    CONSTRAINT FK_SoporteIdioma_Idioma FOREIGN KEY (ID_Idioma) REFERENCES Idioma(ID_Idioma)
);
GO

-- 12. Etiqueta_Comunidad
CREATE TABLE Etiqueta_Comunidad (
    ID_Etiqueta INT IDENTITY(1,1) PRIMARY KEY,
    Nombre_Etiqueta NVARCHAR(100) NOT NULL,
    CONSTRAINT UQ_Etiqueta_Nombre UNIQUE (Nombre_Etiqueta)
);
GO

-- 13. Producto_Etiqueta
CREATE TABLE Producto_Etiqueta (
    ID_Producto INT NOT NULL,
    ID_Etiqueta INT NOT NULL,
    Cantidad_Votos INT NOT NULL DEFAULT 0,
    CONSTRAINT PK_Producto_Etiqueta PRIMARY KEY (ID_Producto, ID_Etiqueta),
    CONSTRAINT FK_ProdEtiq_Producto FOREIGN KEY (ID_Producto) REFERENCES Producto_Digital(ID_Producto),
    CONSTRAINT FK_ProdEtiq_Etiqueta FOREIGN KEY (ID_Etiqueta) REFERENCES Etiqueta_Comunidad(ID_Etiqueta),
    CONSTRAINT CK_ProdEtiq_Votos CHECK (Cantidad_Votos >= 0)
);
GO

-- 14. Mod
CREATE TABLE [Mod] (
    ID_Producto_Base INT NOT NULL,
    ID_Mod INT NOT NULL,
    Nombre_Mod NVARCHAR(150) NOT NULL,
    Descripcion_Mod NVARCHAR(MAX) NOT NULL,
    Tamano_MB DECIMAL(8,2) NOT NULL,
    CONSTRAINT PK_Mod PRIMARY KEY (ID_Producto_Base, ID_Mod),
    CONSTRAINT FK_Mod_JuegoBase FOREIGN KEY (ID_Producto_Base) REFERENCES Juego_Base(ID_Producto),
    CONSTRAINT CK_Mod_Tamano CHECK (Tamano_MB >= 0)
);
GO

-- 15. Usuario
CREATE TABLE Usuario (
    ID_Usuario INT IDENTITY(1,1) PRIMARY KEY,
    Nickname NVARCHAR(50) NOT NULL,
    Correo NVARCHAR(150) NOT NULL,
    Contrasena_Hash NVARCHAR(256) NOT NULL,
    Fecha_Nacimiento DATE NOT NULL,
    Fecha_Registro DATE NOT NULL,
    Pais_Residencia NVARCHAR(60) NOT NULL,
    Estado_Cuenta VARCHAR(20) NOT NULL,
    CONSTRAINT UQ_Usuario_Nickname UNIQUE (Nickname),
    CONSTRAINT UQ_Usuario_Correo UNIQUE (Correo),
    CONSTRAINT CK_Usuario_Estado CHECK (Estado_Cuenta IN ('Activa', 'Suspendida', 'Baneada')),
    CONSTRAINT CK_Usuario_Edad CHECK (Fecha_Nacimiento <= DATEADD(YEAR, -13, Fecha_Registro))
);
GO

-- 16. Amistad_Usuario
CREATE TABLE Amistad_Usuario (
    ID_Usuario_Solicitante INT NOT NULL,
    ID_Usuario_Receptor INT NOT NULL,
    Fecha_Amistad DATE NOT NULL,
    Estado_Amistad VARCHAR(20) NOT NULL,
    CONSTRAINT PK_Amistad_Usuario PRIMARY KEY (ID_Usuario_Solicitante, ID_Usuario_Receptor),
    CONSTRAINT FK_Amistad_Solicitante FOREIGN KEY (ID_Usuario_Solicitante) REFERENCES Usuario(ID_Usuario),
    CONSTRAINT FK_Amistad_Receptor FOREIGN KEY (ID_Usuario_Receptor) REFERENCES Usuario(ID_Usuario),
    CONSTRAINT CK_Amistad_Distintos CHECK (ID_Usuario_Solicitante <> ID_Usuario_Receptor),
    CONSTRAINT CK_Amistad_Estado CHECK (Estado_Amistad IN ('Pendiente', 'Aceptada', 'Bloqueada'))
);
GO

-- 17. Desbloqueo_Logro
CREATE TABLE Desbloqueo_Logro (
    ID_Usuario INT NOT NULL,
    ID_Juego_Base INT NOT NULL,
    ID_Logro INT NOT NULL,
    Fecha_Desbloqueo DATETIME2 NOT NULL,
    CONSTRAINT PK_Desbloqueo_Logro PRIMARY KEY (ID_Usuario, ID_Juego_Base, ID_Logro),
    CONSTRAINT FK_Desbloqueo_Usuario FOREIGN KEY (ID_Usuario) REFERENCES Usuario(ID_Usuario),
    CONSTRAINT FK_Desbloqueo_Logro FOREIGN KEY (ID_Juego_Base, ID_Logro) REFERENCES Logro(ID_Juego_Base, ID_Logro)
);
GO

-- 18. Biblioteca
CREATE TABLE Biblioteca (
    ID_Usuario INT NOT NULL,
    ID_Producto INT NOT NULL,
    Horas_Jugadas DECIMAL(8,2) NOT NULL DEFAULT 0.00,
    Fecha_Ultima_Sesion DATETIME2 NULL,
    CONSTRAINT PK_Biblioteca PRIMARY KEY (ID_Usuario, ID_Producto),
    CONSTRAINT FK_Biblioteca_Usuario FOREIGN KEY (ID_Usuario) REFERENCES Usuario(ID_Usuario),
    CONSTRAINT FK_Biblioteca_Producto FOREIGN KEY (ID_Producto) REFERENCES Producto_Digital(ID_Producto),
    CONSTRAINT CK_Biblioteca_Horas CHECK (Horas_Jugadas >= 0)
);
GO

-- 19. Lista_Deseos
CREATE TABLE Lista_Deseos (
    ID_Usuario INT NOT NULL,
    ID_Producto INT NOT NULL,
    Fecha_Agregado DATE NOT NULL,
    Notificar_Descuento BIT NOT NULL,
    CONSTRAINT PK_Lista_Deseos PRIMARY KEY (ID_Usuario, ID_Producto),
    CONSTRAINT FK_ListaDeseos_Usuario FOREIGN KEY (ID_Usuario) REFERENCES Usuario(ID_Usuario),
    CONSTRAINT FK_ListaDeseos_Producto FOREIGN KEY (ID_Producto) REFERENCES Producto_Digital(ID_Producto)
);
GO

-- 20. Carrito
CREATE TABLE Carrito (
    ID_Usuario INT NOT NULL,
    ID_Producto INT NOT NULL,
    Fecha_Agregado DATE NOT NULL,
    CONSTRAINT PK_Carrito PRIMARY KEY (ID_Usuario, ID_Producto),
    CONSTRAINT FK_Carrito_Usuario FOREIGN KEY (ID_Usuario) REFERENCES Usuario(ID_Usuario),
    CONSTRAINT FK_Carrito_Producto FOREIGN KEY (ID_Producto) REFERENCES Producto_Digital(ID_Producto)
);
GO

-- 21. Resena
CREATE TABLE Resena (
    ID_Resena INT IDENTITY(1,1) PRIMARY KEY,
    ID_Usuario INT NOT NULL,
    ID_Producto INT NOT NULL,
    Texto_Resena NVARCHAR(MAX) NOT NULL,
    Calificacion_1_10 INT NOT NULL,
    Fecha_Publicacion DATE NOT NULL,
    Es_Critica_Especializada BIT NOT NULL,
    CONSTRAINT FK_Resena_Usuario FOREIGN KEY (ID_Usuario) REFERENCES Usuario(ID_Usuario),
    CONSTRAINT FK_Resena_Producto FOREIGN KEY (ID_Producto) REFERENCES Producto_Digital(ID_Producto),
    CONSTRAINT CK_Resena_Calificacion CHECK (Calificacion_1_10 BETWEEN 1 AND 10)
);
GO

-- 22. Suscripcion_Mod
CREATE TABLE Suscripcion_Mod (
    ID_Usuario INT NOT NULL,
    ID_Producto_Base INT NOT NULL,
    ID_Mod INT NOT NULL,
    Fecha_Suscripcion DATE NOT NULL,
    CONSTRAINT PK_Suscripcion_Mod PRIMARY KEY (ID_Usuario, ID_Producto_Base, ID_Mod),
    CONSTRAINT FK_Suscripcion_Usuario FOREIGN KEY (ID_Usuario) REFERENCES Usuario(ID_Usuario),
    CONSTRAINT FK_Suscripcion_Mod FOREIGN KEY (ID_Producto_Base, ID_Mod) REFERENCES [Mod](ID_Producto_Base, ID_Mod)
);
GO

-- 23. Metodo_Pago
CREATE TABLE Metodo_Pago (
    ID_Metodo_Pago INT IDENTITY(1,1) PRIMARY KEY,
    Nombre_Metodo NVARCHAR(100) NOT NULL,
    Moneda VARCHAR(10) NOT NULL,
    Requiere_Validacion BIT NOT NULL,
    CONSTRAINT UQ_MetodoPago_Nombre UNIQUE (Nombre_Metodo)
);
GO

-- 24. Factura
CREATE TABLE Factura (
    ID_Factura INT IDENTITY(1,1) PRIMARY KEY,
    Codigo_Transaccion NVARCHAR(100) NOT NULL,
    Fecha_Hora_Emision DATETIME2 NOT NULL,
    Sub_Total DECIMAL(10,2) NOT NULL,
    Monto_Descuento DECIMAL(10,2) NOT NULL,
    Monto_Impuesto DECIMAL(10,2) NOT NULL,
    Total_Pagado DECIMAL(10,2) NOT NULL,
    ID_Usuario INT NOT NULL,
    ID_Metodo_Pago INT NOT NULL,
    CONSTRAINT UQ_Factura_CodigoTransaccion UNIQUE (Codigo_Transaccion),
    CONSTRAINT FK_Factura_Usuario FOREIGN KEY (ID_Usuario) REFERENCES Usuario(ID_Usuario),
    CONSTRAINT FK_Factura_MetodoPago FOREIGN KEY (ID_Metodo_Pago) REFERENCES Metodo_Pago(ID_Metodo_Pago),
    CONSTRAINT CK_Factura_SubTotal CHECK (Sub_Total >= 0),
    CONSTRAINT CK_Factura_Descuento CHECK (Monto_Descuento >= 0),
    CONSTRAINT CK_Factura_Impuesto CHECK (Monto_Impuesto >= 0),
    CONSTRAINT CK_Factura_Total CHECK (Total_Pagado >= 0)
);
GO

-- 25. Detalle_Factura
CREATE TABLE Detalle_Factura (
    ID_Factura INT NOT NULL,
    ID_Producto INT NOT NULL,
    Precio_Venta_Historico DECIMAL(10,2) NOT NULL,
    Descuento_Aplicado_Pct DECIMAL(5,2) NOT NULL,
    CONSTRAINT PK_Detalle_Factura PRIMARY KEY (ID_Factura, ID_Producto),
    CONSTRAINT FK_Detalle_Factura FOREIGN KEY (ID_Factura) REFERENCES Factura(ID_Factura),
    CONSTRAINT FK_Detalle_Producto FOREIGN KEY (ID_Producto) REFERENCES Producto_Digital(ID_Producto),
    CONSTRAINT CK_Detalle_Precio CHECK (Precio_Venta_Historico >= 0),
    CONSTRAINT CK_Detalle_Descuento CHECK (Descuento_Aplicado_Pct BETWEEN 0 AND 100)
);
GO

-- 26. Reembolso
CREATE TABLE Reembolso (
    ID_Reembolso INT IDENTITY(1,1) PRIMARY KEY,
    ID_Factura INT NOT NULL,
    ID_Producto INT NOT NULL,
    Fecha_Reembolso DATETIME2 NOT NULL,
    Monto_Reembolsado DECIMAL(10,2) NOT NULL,
    Motivo NVARCHAR(250) NOT NULL,
    CONSTRAINT FK_Reembolso_Factura FOREIGN KEY (ID_Factura) REFERENCES Factura(ID_Factura),
    CONSTRAINT FK_Reembolso_Producto FOREIGN KEY (ID_Producto) REFERENCES Producto_Digital(ID_Producto),
    CONSTRAINT CK_Reembolso_Monto CHECK (Monto_Reembolsado >= 0)
);
GO

-- 27. Historial_Descuento
CREATE TABLE Historial_Descuento (
    ID_Producto INT NOT NULL,
    Fecha_Inicio DATE NOT NULL,
    Fecha_Fin DATE NOT NULL,
    Porcentaje_Descuento DECIMAL(5,2) NOT NULL,
    Precio_Base_En_Evento DECIMAL(10,2) NOT NULL,
    Nombre_Evento NVARCHAR(100) NOT NULL,
    CONSTRAINT PK_Historial_Descuento PRIMARY KEY (ID_Producto, Fecha_Inicio),
    CONSTRAINT FK_Historial_Producto FOREIGN KEY (ID_Producto) REFERENCES Producto_Digital(ID_Producto),
    CONSTRAINT CK_Historial_Porcentaje CHECK (Porcentaje_Descuento BETWEEN 0 AND 100),
    CONSTRAINT CK_Historial_PrecioBase CHECK (Precio_Base_En_Evento >= 0),
    CONSTRAINT CK_Historial_Fechas CHECK (Fecha_Fin >= Fecha_Inicio)
);
GO

-- 28. Registro_Concurrencia
CREATE TABLE Registro_Concurrencia (
    ID_Producto INT NOT NULL,
    Fecha_Registro DATE NOT NULL,
    Pico_Maximo_Jugadores INT NOT NULL,
    CONSTRAINT PK_Registro_Concurrencia PRIMARY KEY (ID_Producto, Fecha_Registro),
    CONSTRAINT FK_Concurrencia_Producto FOREIGN KEY (ID_Producto) REFERENCES Producto_Digital(ID_Producto),
    CONSTRAINT CK_Concurrencia_Pico CHECK (Pico_Maximo_Jugadores >= 0)
);
GO
