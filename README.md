El proyecto consiste en construir una base de datos completa en **SQL Server/T-SQL** para una tienda digital: modelo relacional, datos de prueba, consultas analíticas, procedimientos almacenados, funciones, triggers y entrega documentada. Esta lista divide el enunciado en tareas atómicas y en un orden práctico de ejecución.[ppl-ai-file-upload.s3.amazonaws]

# 1. Organización del proyecto

1. Definir una carpeta de trabajo con estos archivos:
    - `DDL.sql`.
    - `Inserts.sql`.
    - `Programmability.sql`.
    - `Queries.sql`.
    - `Informe.pdf` o `Informe.txt`.
2. Definir el orden oficial de ejecución de los scripts.
3. Elegir los tipos de datos definitivos y documentar las decisiones.

# 2. Preparar SQL Server

1. Instalar SQL Server Express 2025.
2. Instalar SQL Server Management Studio.
3. Crear una base de datos para el proyecto.
4. Definir el nombre de la base de datos.
5. Ejecutar una prueba de conexión desde SSMS.
6. Verificar que la instancia permita crear tablas, procedimientos, funciones y triggers.
7. Crear el archivo `DDL.sql`.
8. Crear el archivo `Inserts.sql`.
9. Crear el archivo `Programmability.sql`.
10. Crear el archivo `Queries.sql`.
11. Guardar una copia de seguridad antes de cada etapa importante.

# 3. Diseñar el DDL

## 3.1 Crear la base de datos

1. Crear la base de datos del proyecto.
2. Seleccionarla mediante `USE`. (Sintaxis SQL)
3. Usar `DROP TABLE` controlado o una base limpia durante las pruebas.
4. Evitar incluir datos de prueba dentro de `DDL.sql`.

## 3.2 Definir tipos de datos

Para cada atributo:

1. Elegir `INT` para identificadores numéricos.
2. Elegir `NVARCHAR` para textos y nombres.
3. Elegir `DATE` para fechas sin hora.
4. Elegir `DATETIME2` para fechas con hora.
5. Elegir `DECIMAL(10,2)` o similar para dinero.
6. Elegir `DECIMAL` para horas, tamaños y porcentajes cuando corresponda.
7. Elegir `BIT` para valores booleanos.
8. Definir longitudes razonables para los textos.
9. Documentar en el informe los tipos que requirieron interpretación.

## 3.3 Crear las tablas

Crear las 28 tablas en un orden que respete sus dependencias.

### Catálogo y estructura corporativa

1. Crear `Empresa_Corporativa`.
2. Crear la FK autorreferenciada `ID_Empresa_Matriz`.
3. Crear `Producto_Digital`.
4. Crear `Galeria_Multimedia`.
5. Crear `Juego_Base`.
6. Crear `DLC`.
7. Crear `Perfil_Requisito`.
8. Crear `Logro`.
9. Crear `Categoria_Oficial`.
10. Crear `Juego_Categoria`.
11. Crear `Idioma`.
12. Crear `Soporte_Idioma`.
13. Crear `Etiqueta_Comunidad`.
14. Crear `Producto_Etiqueta`.
15. Crear `Mod`.

### Usuarios y componente social

1. Crear `Usuario`.
2. Crear `Amistad_Usuario`.
3. Crear `Desbloqueo_Logro`.
4. Crear `Biblioteca`.
5. Crear `Lista_Deseos`.
6. Crear `Carrito`.
7. Crear `Resena`.
8. Crear `Suscripcion_Mod`.

### Comercio

1. Crear `Metodo_Pago`.
2. Crear `Factura`.
3. Crear `Detalle_Factura`.
4. Crear `Reembolso`.

### Analítica

1. Crear `Historial_Descuento`.
2. Crear `Registro_Concurrencia`.

Aunque el enunciado enumera 28 elementos, `Empresa_Corporativa` hasta `Registro_Concurrencia` deben revisarse cuidadosamente porque algunas tablas contienen relaciones y claves compuestas.

## 3.4 Definir claves primarias

1. Crear las claves simples.
2. Crear las claves compuestas.
3. Verificar que cada tabla tenga una PK.
4. Usar claves compuestas en las entidades débiles.
5. Implementar, entre otras, las siguientes claves compuestas:
    - `Galeria_Multimedia(ID_Producto, ID_Multimedia)`.
    - `Perfil_Requisito(ID_Producto, Tipo_Perfil)`.
    - `Logro(ID_Juego_Base, ID_Logro)`.
    - `Juego_Categoria(ID_Producto, ID_Categoria)`.
    - `Soporte_Idioma(ID_Producto, ID_Idioma)`.
    - `Producto_Etiqueta(ID_Producto, ID_Etiqueta)`.
    - `Amistad_Usuario(ID_Usuario_Solicitante, ID_Usuario_Receptor)`.
    - `Desbloqueo_Logro(ID_Usuario, ID_Juego_Base, ID_Logro)`.
    - `Biblioteca(ID_Usuario, ID_Producto)`.
    - `Lista_Deseos(ID_Usuario, ID_Producto)`.
    - `Carrito(ID_Usuario, ID_Producto)`.
    - `Suscripcion_Mod(ID_Usuario, ID_Producto_Base, ID_Mod)`.
    - `Detalle_Factura(ID_Factura, ID_Producto)`.
    - `Historial_Descuento(ID_Producto, Fecha_Inicio)`.
    - `Registro_Concurrencia(ID_Producto, Fecha_Registro)`.

## 3.5 Definir claves foráneas

1. Conectar `Empresa_Corporativa` consigo misma.
2. Conectar `Galeria_Multimedia` con `Producto_Digital`.
3. Conectar `Juego_Base` con `Producto_Digital`.
4. Conectar desarrollador y publisher con `Empresa_Corporativa`.
5. Conectar `DLC` con `Producto_Digital`.
6. Conectar `DLC` obligatoriamente con `Juego_Base`.
7. Conectar `Perfil_Requisito` con `Producto_Digital`.
8. Conectar `Logro` con `Juego_Base`.
9. Conectar `Juego_Categoria` con producto y categoría.
10. Conectar `Soporte_Idioma` con producto e idioma.
11. Conectar `Producto_Etiqueta` con producto y etiqueta.
12. Conectar `Mod` con `Juego_Base`.
13. Conectar `Amistad_Usuario` con `Usuario` dos veces.
14. Conectar `Desbloqueo_Logro` con usuario, juego y logro.
15. Conectar `Biblioteca` con usuario y producto.
16. Conectar `Lista_Deseos` con usuario y producto.
17. Conectar `Carrito` con usuario y producto.
18. Conectar `Resena` con usuario y producto.
19. Conectar `Suscripcion_Mod` con usuario, juego y mod.
20. Conectar `Factura` con usuario y método de pago.
21. Conectar `Detalle_Factura` con factura y producto.
22. Conectar `Reembolso` con factura y producto.
23. Conectar `Historial_Descuento` con producto.
24. Conectar `Registro_Concurrencia` con producto.

## 3.6 Implementar restricciones `NOT NULL`

Marcar como obligatorios:

1. Todas las PK.
2. Todas las FK que el modelo define como obligatorias.
3. Nombres y datos necesarios para identificar productos.
4. Precios y datos monetarios.
5. Fechas necesarias para reconstruir operaciones.
6. `Tipo_Producto`.
7. `Clasificacion_Edad`.
8. `Fecha_Nacimiento`.
9. `Fecha_Registro`.
10. Datos necesarios de facturas y detalles.
11. Campos indispensables para descuentos e historial.

Permitir `NULL` únicamente cuando tenga sentido, por ejemplo:

- `ID_Empresa_Matriz` para empresas raíz.
- `Subtipo_Jugable` cuando el DLC no sea jugable.
- Descripciones opcionales.
- `Fecha_Reembolso`, si el modelo realmente permite reembolsos pendientes; de lo contrario, hacerla obligatoria.
- Campos opcionales de producto.

## 3.7 Implementar restricciones de dominio

Crear `CHECK` para:

1. `Producto_Digital.Tipo_Producto`:
    - `Juego_Base`.
    - `DLC`.
2. `Producto_Digital.Clasificacion_Edad`:
    - `E`.
    - `T`.
    - `M`.
    - `AO`.
3. `Producto_Digital.Metacritic_Score` entre 0 y 100.
4. `Producto_Digital.Precio_Base_Actual >= 0`.
5. `DLC.Tipo_Contenido`:
    - `Jugable`.
    - `Banda_Sonora`.
    - `Arte`.
6. `DLC.Subtipo_Jugable`:
    - `Personaje`.
    - `Mapa`.
    - `Modo_Juego`.
    - `Cosmetico`.
7. Verificar que `Subtipo_Jugable` solo tenga valor cuando `Tipo_Contenido = 'Jugable'`.
8. `Perfil_Requisito.Tipo_Perfil`:
    - `Minimo`.
    - `Recomendado`.
9. `Galeria_Multimedia.Tipo_Archivo`:
    - `Foto`.
    - `Video`.
10. `Usuario.Estado_Cuenta`:
    - `Activa`.
    - `Suspendida`.
    - `Baneada`.
11. `Amistad_Usuario.Estado_Amistad`:
    - `Pendiente`.
    - `Aceptada`.
    - `Bloqueada`.
12. `Resena.Calificacion_1_10` entre 1 y 10.
13. `Historial_Descuento.Porcentaje_Descuento` entre 0 y 100.
14. `Historial_Descuento.Fecha_Fin >= Fecha_Inicio`.
15. Todos los campos monetarios mayores o iguales que cero:
    - `Precio_Base_Actual`.
    - `Sub_Total`.
    - `Monto_Descuento`.
    - `Monto_Impuesto`.
    - `Total_Pagado`.
    - `Precio_Venta_Historico`.
    - `Monto_Reembolsado`.
16. `Tamano_GB >= 0`.
17. `Tamano_MB >= 0`.
18. `Horas_Jugadas >= 0`.
19. `Cantidad_Votos >= 0`.
20. `Pico_Maximo_Jugadores >= 0`.

## 3.8 Implementar restricciones de unicidad

Agregar `UNIQUE` para:

1. `Usuario.Nickname`.
2. `Usuario.Correo`.
3. `Factura.Codigo_Transaccion`.
4. `Empresa_Corporativa.Nombre`, si el modelo lo permite.
5. `Categoria_Oficial.Nombre_Categoria`.
6. `Idioma.Nombre_Idioma`.
7. `Etiqueta_Comunidad.Nombre_Etiqueta`.
8. `Metodo_Pago.Nombre_Metodo`, si corresponde.

## 3.9 Probar el DDL

1. Ejecutar `DDL.sql` en una base vacía.
2. Verificar que todas las tablas se creen.
3. Consultar las columnas con las vistas del sistema.
4. Consultar las PK.
5. Consultar las FK.
6. Intentar insertar un valor monetario negativo.
7. Intentar insertar una clasificación inválida.
8. Intentar insertar una calificación fuera de 1 a 10.
9. Intentar crear un DLC sin juego base.
10. Intentar borrar un juego que tenga DLC, logros o biblioteca.
11. Registrar los resultados de las pruebas.

# 4. Preparar el Data Seeding

Crear `Inserts.sql` respetando este orden general:

1. Ejecutar el script `Lookups.sql`.
2. Insertar empresas.
3. Insertar productos digitales.
4. Insertar juegos base.
5. Insertar DLC.
6. Insertar perfiles de requisitos.
7. Insertar logros.
8. Insertar categorías, idiomas y métodos si no vienen completamente cargados.
9. Insertar etiquetas.
10. Insertar mods.
11. Insertar usuarios.
12. Insertar relaciones sociales.
13. Insertar soporte de idiomas.
14. Insertar categorías de juegos.
15. Insertar etiquetas de productos.
16. Insertar biblioteca inicial, si corresponde.
17. Insertar listas de deseos.
18. Insertar carritos.
19. Insertar descuentos históricos.
20. Insertar concurrencia.
21. Insertar facturas.
22. Insertar detalles de factura.
23. Insertar reseñas.
24. Insertar desbloqueos.
25. Insertar suscripciones a mods.
26. Insertar reembolsos.
27. Validar todas las cantidades mínimas.

# 5. Insertar empresas

1. Insertar al menos 40 empresas.
2. Crear al menos 8 empresas con `ID_Empresa_Matriz`.
3. Insertar primero las empresas raíz.
4. Insertar después las subsidiarias.
5. Crear jerarquías reales matriz-subsidiaria.
6. Asegurar que existan estudios desarrolladores.
7. Asegurar que algunas empresas sean publisher.
8. Asegurar que algunas empresas cumplan ambos roles:
    - Desarrollador de unos juegos.
    - Publisher de otros juegos.
9. Evitar nombres genéricos sin sentido.
10. Verificar que las jerarquías no formen ciclos.

# 6. Insertar productos

1. Insertar como mínimo 300 productos.
2. Crear aproximadamente 70% de juegos base.
3. Crear aproximadamente 30% de DLC.
4. Insertar primero todos los juegos base.
5. Insertar después los DLC.
6. Vincular cada DLC con un juego base existente.
7. Insertar al menos 15 productos con clasificación `M` o `AO`.
8. Insertar al menos 20 DLC gratuitos.
9. Usar precios realistas.
10. Usar fechas de lanzamiento variadas.
11. Insertar descripciones significativas.
12. Asignar desarrolladores y publishers existentes.
13. Verificar que no existan DLC huérfanos.
14. Crear el producto especial `Los Sims 4`.
15. Crear al menos 5 DLC asociados a `Los Sims 4`.
16. Crear el producto especial `Overcooked`.
17. Crear suficientes datos para consultas sobre categorías, ventas y reseñas.

# 7. Completar fichas de juegos base

Para cada juego base:

1. Insertar un perfil `Minimo`.
2. Insertar un perfil `Recomendado`.
3. Insertar al menos dos idiomas.
4. Insertar entre 5 y 30 logros.
5. Asociar un estudio desarrollador.
6. Asociar un publisher.
7. Definir motor gráfico.
8. Definir compras dentro del juego.
9. Definir soporte para guardado en la nube.
10. Verificar que los dos perfiles sean distintos.
11. Verificar que todos los logros pertenezcan a un juego base.
12. Crear datos suficientes para que algunos usuarios desbloqueen todos los logros de un juego.

# 8. Insertar galería, etiquetas y mods

## Galería

1. Asociar al menos 2 archivos multimedia al 80% de los productos.
2. Usar únicamente `Foto` o `Video`.
3. Generar URLs coherentes.
4. Evitar URL vacías o repetidas cuando no corresponda.
5. Verificar la cobertura mínima.

## Etiquetas

1. Crear al menos 50 etiquetas distintas.
2. Asociar etiquetas a productos.
3. Insertar `Cantidad_Votos` coherente.
4. Crear productos publicados en el último año con etiquetas.
5. Garantizar datos para el reporte de tendencias.

## Mods

1. Crear mods para varios juegos base.
2. Asociar nombres y descripciones significativas.
3. Insertar tamaños válidos en MB.
4. Crear suficientes mods para permitir suscripciones.
5. Crear al menos un escenario completo para `Los Sims 4`.

# 9. Insertar usuarios y relaciones sociales

## Usuarios

1. Insertar al menos 250 usuarios.
2. Distribuir `Fecha_Registro` durante los últimos 2 años.
3. Distribuir usuarios entre distintos países.
4. Hacer que al menos 10% estén suspendidos o baneados.
5. Respetar la edad mínima de 13 años.
6. Crear correos con diferentes dominios.
7. Crear suficientes usuarios con dominios repetidos.
8. Garantizar que al menos un dominio tenga más de 10 usuarios.
9. Insertar contraseñas como hashes simulados, nunca texto plano real.
10. Crear usuarios activos para los reportes de compras y biblioteca.

## Amistades

1. Insertar al menos 300 relaciones.
2. Usar estados `Pendiente`, `Aceptada` y `Bloqueada`.
3. Crear relaciones aceptadas bidireccionales cuando corresponda.
4. Evitar una amistad de un usuario consigo mismo.
5. Crear redes con hasta 3 grados de separación.
6. Crear datos para el caso de `Overcooked`.
7. Asegurar que algunos amigos activos posean el mismo juego.

# 10. Preparar datos de comercio

## Facturas

1. Insertar al menos 500 facturas.
2. Distribuirlas en los últimos 2 años.
3. Asociarlas a usuarios existentes.
4. Asociarlas a métodos de pago provenientes de `Lookups.sql`.
5. Crear códigos de transacción únicos.
6. Calcular `Sub_Total`.
7. Calcular `Monto_Descuento`.
8. Calcular `Monto_Impuesto`.
9. Calcular `Total_Pagado`.
10. Verificar que la fórmula financiera sea consistente.

## Detalles

1. Insertar entre 1 y 5 productos por factura.
2. Guardar el precio histórico de cada producto.
3. Guardar el porcentaje de descuento aplicado.
4. Crear líneas con descuento 0%.
5. Crear suficientes ventas sin descuento para el reporte de precio completo.
6. Crear usuarios que compren juegos de distintas categorías.
7. Crear compras del juego base y DLC de `Los Sims 4`.
8. Crear compras de `Overcooked`.
9. Evitar duplicar el mismo producto dentro de una factura.

## Biblioteca

1. Crear registros coherentes con las compras.
2. Insertar horas jugadas variadas.
3. Insertar fechas de última sesión.
4. Crear usuarios con al menos un producto.
5. Crear usuarios sin reseñas ni logros para el reporte de lurkers.
6. Crear usuarios que posean categorías de estrategia y terror.
7. Crear usuarios con todos los logros de un juego.
8. Crear usuarios con el juego base `Los Sims 4`.
9. Crear usuarios con al menos cinco DLC de `Los Sims 4`.
10. Crear usuarios con `Overcooked`.

## Deseos y carritos

1. Insertar listas de deseos.
2. Insertar carritos activos.
3. No insertar en el carrito productos que el usuario ya posea.
4. Crear carritos con DLC y su juego base cuando sea necesario.
5. Crear datos suficientes para probar `sp_realizar_compra`.

# 11. Insertar descuentos y analítica

## Descuentos

1. Insertar eventos con nombres reales:
    - `Summer Sale`.
    - `Winter Fest`.
    - `Halloween Sale`.
    - `Publisher Weekend`.
2. Crear descuentos para varios productos.
3. Crear fechas de inicio y fin válidas.
4. Hacer que algunos descuentos se solapen con fechas de compras.
5. Guardar `Precio_Base_En_Evento`.
6. Crear descuentos de distintos porcentajes.
7. Crear productos con y sin descuento.
8. Verificar que el precio histórico pueda reconstruirse.

## Concurrencia

1. Insertar registros para al menos 50 productos populares.
2. Crear varias fechas por producto.
3. Insertar picos de jugadores realistas.
4. Verificar que las fechas permitan análisis temporal.

# 12. Insertar reembolsos

1. Insertar al menos 30 reembolsos.
2. Asociarlos a facturas existentes.
3. Asociarlos a productos realmente comprados.
4. Usar fechas posteriores a la compra.
5. Usar montos no negativos.
6. Crear reembolsos dentro y fuera de períodos de análisis.
7. Evitar reembolsar dos veces la misma línea, salvo que el modelo lo permita.
8. Crear datos para reportes de facturación neta.
9. Verificar que existan productos sin reembolso para “Juegos de Élite”.

# 13. Insertar reseñas y logros

## Reseñas

1. Insertar al menos 800 reseñas.
2. Mezclar usuarios regulares y críticos especializados.
3. Usar calificaciones entre 1 y 10.
4. Crear juegos con al menos 20 reseñas.
5. Crear juegos cuyo promedio sea menor que el promedio general.
6. Crear calificaciones menores a 4.
7. Crear juegos con promedios entre:
    - Menos de 4.
    - 4 a 5.9.
    - 6 a 6.9.
8. Evitar que todos los juegos tengan el mismo promedio.
9. Verificar que las reseñas estén vinculadas a productos existentes.

## Logros

1. Insertar desbloqueos para usuarios con juegos en su biblioteca.
2. Crear al menos un usuario que desbloquee todos los logros de un juego.
3. Crear usuarios con menos del 10% de logros desbloqueados.
4. Crear juegos sin logros solo si se desea probar exclusiones.
5. Crear juegos con varios logros para evaluar la consulta de críticos inexpertos.

# 14. Implementar funciones

Crear las funciones en `Programmability.sql` antes de los procedimientos y consultas que las utilicen.

## 14.1 `fn_calcular_impuesto`

1. Crear una función escalar.
2. Recibir únicamente `@monto`.
3. Definir el IVA del 16% en un único punto.
4. Devolver `@monto * 0.16`.
5. Evitar devolver valores negativos.
6. Probar con cero.
7. Probar con un monto positivo.

## 14.2 `fn_precio_con_descuento`

1. Recibir `@ID_Producto`.
2. Recibir `@fecha`.
3. Buscar un descuento vigente.
4. Comparar la fecha con `Fecha_Inicio` y `Fecha_Fin`.
5. Usar `Precio_Base_En_Evento`, no `Precio_Base_Actual`, cuando exista descuento.
6. Aplicar el porcentaje de descuento.
7. Devolver `Precio_Base_Actual` si no hay descuento.
8. Resolver qué hacer si existen varios descuentos vigentes.
9. Documentar esa decisión.
10. Probar un producto con descuento.
11. Probar un producto sin descuento.

## 14.3 `fn_clasificar_ingreso`

1. Recibir `@monto`.
2. Devolver `AAA` si el monto es mayor que 10.000.
3. Devolver `Consolidado` entre 2.000 y 10.000.
4. Devolver `Indie` si es menor que 2.000.
5. Probar los valores límite.

## 14.4 `fn_calcular_reputacion`

1. Recibir `@ID_Producto`.
2. Calcular promedio de calificaciones.
3. Calcular total de jugadores.
4. Consultar `Metacritic_Score`.
5. Aplicar la fórmula sugerida.
6. Limitar el resultado máximo a 100.
7. Devolver `DECIMAL(5,2)`.
8. Decidir cómo tratar productos sin reseñas.
9. Documentar el criterio.
10. Probar juegos con y sin reseñas.

## 14.5 `fn_calcular_horas_totales_usuario`

1. Recibir `@ID_Usuario`.
2. Sumar `Horas_Jugadas` de `Biblioteca`.
3. Devolver `0.0` si no existen registros.
4. Devolver `DECIMAL(10,2)`.
5. Probar un usuario con biblioteca.
6. Probar un usuario sin biblioteca.

# 15. Implementar triggers

## 15.1 Trigger de auditoría de precios

1. Crear un trigger `AFTER UPDATE` sobre `Producto_Digital`.
2. Detectar cambios en `Precio_Base_Actual`.
3. Comparar precio nuevo y anterior.
4. Permitir cambios de hasta 50%.
5. No aplicar la restricción si el precio anterior era cero.
6. Impedir aumentos bruscos.
7. Impedir reducciones bruscas.
8. Levantar error con `RAISERROR` o equivalente.
9. Hacer rollback de la operación.
10. Probar cambios válidos.
11. Probar cambios inválidos.
12. Probar precio anterior igual a cero.

## 15.2 Trigger de protección de menores

1. Crear un trigger sobre `Detalle_Factura`.
2. Obtener el usuario de la factura.
3. Obtener la clasificación del producto.
4. Detectar clasificaciones `M` y `AO`.
5. Obtener `Fecha_Nacimiento`.
6. Calcular la edad.
7. Rechazar menores de 18 años.
8. Generar exactamente el mensaje:
    - `Contenido restringido por edad`.
9. Probar con usuario menor.
10. Probar con usuario adulto.

## 15.3 Trigger de biblioteca automática

1. Crear un trigger `AFTER INSERT` sobre `Detalle_Factura`.
2. Obtener el usuario asociado a cada factura.
3. Insertar los productos en `Biblioteca`.
4. Usar `Horas_Jugadas = 0`.
5. Evitar duplicados.
6. Probar una compra con varios productos.
7. Verificar que la biblioteca se actualice.

## 15.4 Trigger de revocación por reembolso

1. Crear un trigger `AFTER INSERT` sobre `Reembolso`.
2. Identificar el usuario de la factura.
3. Identificar el producto reembolsado.
4. Eliminar el producto de `Biblioteca`.
5. Probar un reembolso válido.
6. Verificar que se elimine el acceso.

## 15.5 Trigger de validación de carrito

1. Crear un trigger `INSTEAD OF INSERT` o `AFTER INSERT` sobre `Carrito`.
2. Verificar que el usuario no posea el producto.
3. Obtener el tipo de producto.
4. Si es DLC, obtener su juego base.
5. Verificar que el usuario posea el juego base.
6. Permitir el DLC si el juego base está en el mismo carrito.
7. Rechazar condiciones inválidas.
8. Utilizar `RAISERROR`.
9. Probar agregar un juego que ya existe en biblioteca.
10. Probar agregar un DLC sin juego base.
11. Probar agregar un DLC con el juego base en biblioteca.
12. Probar agregar simultáneamente juego base y DLC.

# 16. Implementar procedimientos almacenados

## 16.1 `sp_realizar_compra`

1. Definir parámetros:
    - `@ID_Usuario`.
    - `@ID_Metodo_Pago`.
2. Verificar que el usuario exista.
3. Verificar que el método de pago exista.
4. Verificar que el carrito no esté vacío.
5. Verificar que el usuario no posea productos del carrito.
6. Iniciar una transacción.
7. Leer los productos del carrito.
8. Calcular precio efectivo usando `fn_precio_con_descuento`.
9. Calcular descuento por línea.
10. Calcular subtotal.
11. Calcular impuesto usando `fn_calcular_impuesto`.
12. Calcular total pagado.
13. Generar `ID_Factura`.
14. Insertar la factura.
15. Insertar los detalles.
16. Dejar que el trigger pueble la biblioteca.
17. Vaciar el carrito.
18. Confirmar con `COMMIT`.
19. Usar `TRY/CATCH`.
20. Hacer `ROLLBACK` ante error.
21. Probar carrito vacío.
22. Probar compra válida.
23. Probar compra con contenido restringido.
24. Probar error durante la operación.

## 16.2 `sp_dashboard_estudio`

1. Recibir `@ID_Empresa`.
2. Recibir fecha inicial.
3. Recibir fecha final.
4. Validar que el estudio exista.
5. Generar el primer result set:
    - Ingreso total.
    - Unidades vendidas.
    - Reembolsos.
6. Generar el segundo result set:
    - Los 5 juegos más vendidos.
7. Generar el tercer result set:
    - Los 5 mejores compradores.
8. Filtrar todas las operaciones por el rango de fechas.
9. Excluir DLC si el requerimiento se refiere a juegos base.
10. Ordenar correctamente los resultados.
11. Probar con distintos estudios.
12. Probar períodos sin ventas.

## 16.3 `sp_publicar_producto_con_etiquetas`

1. Recibir datos generales del producto.
2. Recibir la naturaleza del producto.
3. Recibir la cadena de etiquetas separadas por comas.
4. Validar que la naturaleza sea `Juego_Base` o `DLC`.
5. Validar que el juego base exista si se publica un DLC.
6. Iniciar una transacción.
7. Insertar en `Producto_Digital`.
8. Insertar en `Juego_Base` o `DLC`.
9. Separar las etiquetas.
10. Limpiar espacios.
11. Buscar cada etiqueta.
12. Crear las etiquetas inexistentes.
13. Insertar o actualizar `Producto_Etiqueta`.
14. Confirmar con `COMMIT`.
15. Revertir todo con `ROLLBACK` si falla algo.
16. Probar etiquetas existentes.
17. Probar etiquetas nuevas.
18. Probar publicación de juego base.
19. Probar publicación de DLC.

## 16.4 `sp_procesar_reembolso`

1. Recibir `@ID_Factura`.
2. Recibir `@ID_Producto`.
3. Recibir `@Motivo`.
4. Verificar que exista la línea de factura.
5. Verificar que la compra tenga menos de 14 días.
6. Verificar que el usuario tenga el producto en biblioteca.
7. Verificar que haya jugado menos de 2 horas.
8. Obtener el precio desde `Detalle_Factura`.
9. Iniciar una transacción.
10. Insertar en `Reembolso`.
11. Permitir que el trigger elimine el producto de biblioteca.
12. Confirmar la transacción.
13. Revertir ante error.
14. Probar una compra antigua.
15. Probar más de 2 horas.
16. Probar reembolso válido.
17. Probar producto inexistente.

## 16.5 `sp_desbloquear_logro`

1. Recibir `@ID_Usuario`.
2. Recibir `@ID_Juego_Base`.
3. Recibir `@ID_Logro`.
4. Verificar que el juego exista.
5. Verificar que el logro exista.
6. Verificar que el logro pertenezca al juego indicado.
7. Verificar que el usuario tenga el juego en biblioteca.
8. Verificar que no haya desbloqueado previamente el logro.
9. Iniciar una transacción.
10. Insertar en `Desbloqueo_Logro`.
11. Usar `GETDATE()`.
12. Confirmar con `COMMIT`.
13. Revertir ante error.
14. Probar logro válido.
15. Probar logro inexistente.
16. Probar usuario sin el juego.
17. Probar desbloqueo duplicado.

# 17. Implementar las consultas de reportes

Crear en `Queries.sql` las 20 consultas solicitadas. Cada consulta debe devolver exactamente las columnas indicadas.

## Consulta 1: Clasificación de estudios por facturación

1. Filtrar facturas del último mes.
2. Relacionar detalles con productos.
3. Identificar juegos desarrollados por cada estudio.
4. Calcular juegos vendidos.
5. Calcular ingreso total.
6. Invocar `fn_clasificar_ingreso`.
7. Mostrar:
    - `Estudio`.
    - `Pais_Origen`.
    - `Juegos_Vendidos`.
    - `Ingreso_Total`.
    - `Clasificacion`.

## Consulta 2: Éxito por categoría

1. Relacionar categorías y productos.
2. Obtener unidades vendidas.
3. Contar reseñas.
4. Obtener `Metacritic_Score`.
5. Calcular:
    - `(Unidades_Vendidas * 2) + (Total_Reseñas * 1.5) + Metacritic_Score`.
6. Seleccionar el producto máximo por categoría.
7. Mostrar:
    - `Nombre_Categoria`.
    - `Titulo`.
    - `Estudio`.
    - `Puntaje_Popularidad`.

## Consulta 3: Dominios de correo

1. Extraer la parte posterior a `@`.
2. Agrupar por dominio.
3. Contar usuarios.
4. Filtrar dominios con más de 10 usuarios.
5. Mostrar:
    - `Dominio`.
    - `Cantidad_Usuarios`.

## Consulta 4: Recompra temprana

1. Ordenar compras por usuario y fecha.
2. Obtener la primera compra.
3. Obtener la segunda compra.
4. Calcular días entre ambas.
5. Filtrar diferencias de hasta 30 días.
6. Mostrar:
    - `Nickname`.
    - `Fecha_Primera_Compra`.
    - `Fecha_Segunda_Compra`.
    - `Dias_Entre_Compras`.

## Consulta 5: Peso del catálogo por estudio

1. Filtrar juegos base.
2. Agrupar por estudio desarrollador.
3. Sumar `Tamano_GB`.
4. Contar juegos.
5. Convertir el tamaño a GB o TB.
6. Formatear `Peso_Total`.
7. Mostrar:
    - `Estudio`.
    - `Cantidad_Juegos`.
    - `Peso_Total`.

## Consulta 6: Mapa de calor financiero

1. Agrupar ventas por país del comprador.
2. Calcular ingresos brutos.
3. Calcular reembolsos.
4. Calcular ingresos netos.
5. Calcular el total global.
6. Calcular la participación porcentual.
7. Formatear `Share`.
8. Mostrar:
    - `Pais`.
    - `Total_Neto`.
    - `Share`.

## Consulta 7: Bibliotecas cruzadas

1. Encontrar usuarios con juegos de categoría `Estrategia`.
2. Encontrar usuarios con juegos de categoría `Terror`.
3. Intersectar ambos conjuntos.
4. Calcular gasto histórico.
5. Filtrar gasto mayor que 100 USD.
6. Mostrar:
    - `Nickname`.
    - `Gasto_Total_Historico`.

## Consulta 8: Generaciones

1. Clasificar por año de nacimiento.
2. Crear `CASE` para:
    - Gen Z: año mayor que 2000.
    - Millennials: 1981 a 2000.
    - Gen X y anteriores: menor que 1981.
3. Filtrar usuarios activos.
4. Contar usuarios.
5. Calcular gasto promedio.
6. Mostrar:
    - `Generacion`.
    - `Cantidad_Usuarios_Activos`.
    - `Gasto_Promedio`.

## Consulta 9: Juegos polémicos

1. Filtrar juegos base.
2. Contar reseñas.
3. Calcular promedio por juego.
4. Calcular promedio general de la plataforma.
5. Filtrar juegos con al menos 20 reseñas.
6. Filtrar promedios menores al promedio general.
7. Etiquetar mediante `CASE`:
    - `Crítico`.
    - `Mixto`.
    - `Divisivo`.
8. Mostrar:
    - `Titulo`.
    - `Total_Resenas`.
    - `Promedio_Calificacion`.
    - `Veredicto`.

## Consulta 10: Juegos de élite

1. Filtrar juegos sin reembolsos.
2. Filtrar juegos con al menos 20 reseñas.
3. Calcular promedio de cada juego.
4. Calcular promedio de su estudio desarrollador.
5. Comparar ambos promedios.
6. Invocar `fn_calcular_reputacion`.
7. Calcular reputación promedio global.
8. Filtrar reputación superior a la media.
9. Ordenar por reputación descendente.
10. Mostrar:
    - `Titulo`.
    - `Estudio`.
    - `Total_Jugadores`.
    - `Promedio_Calificacion`.
    - `Puntaje_Reputacion`.

## Consulta 11: Usuarios lurkers

1. Encontrar usuarios con biblioteca no vacía.
2. Excluir usuarios con reseñas.
3. Excluir usuarios con logros desbloqueados.
4. Obtener la última sesión.
5. Contar juegos en biblioteca.
6. Mostrar:
    - `Nickname`.
    - `Fecha_Ultima_Sesion`.
    - `Juegos_En_Biblioteca`.

## Consulta 12: Tendencias de etiquetas

1. Filtrar productos lanzados en el último año.
2. Relacionar productos con etiquetas.
3. Sumar `Cantidad_Votos`.
4. Contar productos asociados.
5. Ordenar por votos descendentes.
6. Tomar las primeras 3 etiquetas.
7. Mostrar:
    - `Nombre_Etiqueta`.
    - `Votos_Totales`.
    - `Productos_Asociados`.

## Consulta 13: Coleccionistas completos

1. Obtener logros de cada juego.
2. Obtener logros desbloqueados por usuario.
3. Comparar ambos conjuntos.
4. Aplicar división relacional.
5. Seleccionar usuarios que desbloquearon todos los logros.
6. Mostrar:
    - `Nickname`.
    - `Titulo_Juego`.
    - `Total_Logros`.

## Consulta 14: Liquidación de regalías

1. Filtrar ventas del mes actual.
2. Filtrar juegos base.
3. Agrupar por estudio desarrollador.
4. Calcular ingreso bruto.
5. Calcular reembolsos.
6. Calcular ingreso neto.
7. Invocar `fn_clasificar_ingreso` usando ingreso bruto.
8. Asignar comisión:
    - AAA: 30%.
    - Consolidado: 25%.
    - Indie: 20%.
9. Calcular monto a pagar.
10. Calcular promedio de montos a pagar.
11. Filtrar montos superiores al promedio.
12. Mostrar:
    - `Estudio`.
    - `Pais_Origen`.
    - `Ingreso_Bruto`.
    - `Reembolsos`.
    - `Ingreso_Neto`.
    - `Tramo_Comision`.
    - `Comision`.
    - `Monto_A_Pagar`.

## Consulta 15: Ecosistema Los Sims 4

1. Encontrar `Los Sims 4`.
2. Encontrar sus DLC.
3. Encontrar usuarios que poseen el juego base.
4. Contar DLC comprados.
5. Filtrar al menos 5 DLC.
6. Contar mods suscritos del juego.
7. Filtrar al menos una suscripción.
8. Sumar pagos del juego base y DLC.
9. Restar reembolsos.
10. Ordenar por dinero invertido descendente.
11. Mostrar:
    - `Nickname`.
    - `Cantidad_DLCs`.
    - `Mods_Suscritos`.
    - `Dinero_Invertido`.

## Consulta 16: Red cooperativa de Overcooked

1. Encontrar `Overcooked`.
2. Encontrar usuarios que lo poseen.
3. Obtener amistades aceptadas.
4. Tratar la relación como bidireccional.
5. Verificar cuáles amigos poseen `Overcooked`.
6. Contar amigos con el juego.
7. Obtener horas jugadas del usuario.
8. Filtrar al menos 2 amigos.
9. Ordenar descendente por cantidad de amigos.
10. Mostrar:
    - `Nickname`.
    - `Horas_Jugadas`.
    - `Amigos_Con_Juego`.

## Consulta 17: Éxito a precio completo

1. Calcular el promedio general de precios de juegos base.
2. Filtrar juegos con precio estrictamente superior al promedio.
3. Contar ventas con `Descuento_Aplicado_Pct = 0`.
4. Filtrar más de 50 ventas a precio completo.
5. Contar idiomas soportados.
6. Filtrar al menos 4 idiomas.
7. Mostrar:
    - `Titulo`.
    - `Precio_Base_Actual`.
    - `Idiomas_Soportados`.
    - `Ventas_Full_Price`.

## Consulta 18: Imperios corporativos

1. Identificar empresas matriz.
2. Excluir empresas independientes.
3. Construir una CTE recursiva.
4. Recorrer subsidiarias directas.
5. Recorrer subsidiarias indirectas.
6. Calcular el nivel jerárquico.
7. Contar productos desarrollados por cada subsidiaria.
8. Calcular ventas del mes actual.
9. Calcular reembolsos del mes actual.
10. Calcular ingreso neto mensual.
11. Mostrar:
    - `Empresa_Matriz_Principal`.
    - `Empresa_Subsidiaria`.
    - `Nivel_Jerarquia`.
    - `Productos_Desarrollados`.
    - `Ingreso_Neto_Mensual`.

## Consulta 19: Críticos inexpertos

1. Filtrar reseñas de juegos base.
2. Filtrar calificaciones menores que 4.
3. Contar logros totales del juego.
4. Contar logros desbloqueados por el usuario.
5. Excluir juegos sin logros.
6. Calcular el porcentaje de avance.
7. Filtrar menos del 10%.
8. Mostrar:
    - `Nickname`.
    - `Titulo`.
    - `Calificacion_1_10`.
    - `Cantidad_Logros_Desbloqueados`.
    - `Total_Logros`.

## Consulta 20: Círculos de confianza

1. Declarar la variable:
    
    ```
    DECLARE @ID_Usuario INT = <valor>;
    ```
    
2. Crear una CTE recursiva.
3. Interpretar `Amistad_Usuario` como relación bidireccional.
4. Filtrar amistades aceptadas.
5. Empezar desde el usuario indicado.
6. Recorrer hasta tres grados.
7. Evitar ciclos.
8. Calcular el grado mínimo de cada contacto.
9. Excluir al usuario de origen.
10. Clasificar mediante `CASE`:
    - Grado 1: `Amigo directo`.
    - Grado 2: `Amigo de un amigo`.
    - Grado 3: `Contacto lejano`.
11. Obtener juegos base del contacto.
12. Excluir juegos que ya tenga el usuario de origen.
13. Contar juegos recomendables.
14. Filtrar al menos un juego recomendable.
15. Ordenar por grado ascendente.
16. Ordenar luego por recomendaciones descendentes.
17. Mostrar:
    - `Nickname_Contacto`.
    - `Grado_Separacion`.
    - `Cercania`.
    - `Juegos_Recomendables`.

# 18. Probar la programabilidad

Para cada función, procedimiento y trigger:

1. Crear un caso de prueba válido.
2. Crear un caso de prueba inválido.
3. Verificar mensajes de error.
4. Verificar que las transacciones hagan `ROLLBACK`.
5. Verificar que los triggers no creen duplicados.
6. Verificar que las funciones devuelvan tipos correctos.
7. Verificar que los procedimientos devuelvan los result sets solicitados.
8. Verificar que las consultas no devuelvan resultados vacíos.
9. Corregir los datos si un reporte queda vacío.
10. Separar las pruebas del código final o comentarlas claramente.

# 19. Validar los datos mínimos

Crear consultas de conteo para comprobar:

1. Empresas: al menos 40.
2. Subsidiarias: al menos 8.
3. Productos: al menos 300.
4. Juegos base: aproximadamente 70%.
5. DLC: aproximadamente 30%.
6. Productos adultos: al menos 15.
7. DLC gratuitos: al menos 20.
8. Perfiles por juego: 2.
9. Idiomas por juego: al menos 2.
10. Logros por juego: entre 5 y 30.
11. Etiquetas distintas: al menos 50.
12. Galería: al menos 80% de productos.
13. Usuarios: al menos 250.
14. Usuarios suspendidos o baneados: al menos 10%.
15. Amistades: al menos 300.
16. Facturas: al menos 500.
17. Productos por factura: entre 1 y 5.
18. Reembolsos: al menos 30.
19. Reseñas: al menos 800.
20. Productos con concurrencia: al menos 50.
21. Usuarios con logros completos.
22. Usuarios con compras de múltiples categorías.
23. Usuarios con carritos activos.
24. Usuarios con listas de deseos.
25. Usuarios con suscripciones a mods.

# 20. Revisar consistencia financiera

1. Verificar que `Sub_Total` sea la suma de precios antes de descuento.
2. Verificar que `Monto_Descuento` sea la diferencia correspondiente.
3. Verificar que `Monto_Impuesto` sea el 16% definido.
4. Verificar que `Total_Pagado` coincida con la fórmula elegida.
5. Documentar si el impuesto se calcula antes o después del descuento.
6. Verificar que `Precio_Venta_Historico` nunca cambie después de la compra.
7. Verificar que `Descuento_Aplicado_Pct` represente el porcentaje vigente.
8. Verificar que los reembolsos no excedan el monto comprado.
9. Verificar que el ingreso neto sea ventas menos reembolsos.
10. Verificar que las regalías usen el ingreso bruto para determinar el tramo.

# 21. Preparar el informe

El informe debe contener:

1. Nombre de la universidad.
2. Nombre de la asignatura.
3. Nombre del proyecto.
4. Integrantes.
5. Cédulas o identificadores solicitados por el curso.
6. Descripción general del sistema.
7. Descripción de las tablas.
8. Diagrama o explicación del modelo, si lo solicitan.
9. Tipos de datos elegidos.
10. Justificación de `DECIMAL`, `DATE`, `DATETIME2`, `BIT`, etc.
11. Explicación de las restricciones.
12. Explicación de las claves compuestas.
13. Explicación de los triggers.
14. Explicación de las funciones.
15. Explicación de los procedimientos almacenados.
16. Explicación de las consultas complejas.
17. Decisiones sobre:
    - Impuestos.
    - Reembolsos.
    - Descuentos solapados.
    - Edad.
    - Precio histórico.
    - Relaciones de amistad.
    - Reputación.
18. Orden de ejecución de los scripts.
19. Requisitos mínimos de datos sembrados.
20. Evidencias de ejecución.
21. Resultados o capturas de pruebas.
22. Limitaciones conocidas.
23. Nombre final del archivo `.rar`.

# 22. Definir orden de ejecución

El informe debe indicar un orden similar a este:

1. Crear la base de datos.
2. Ejecutar `DDL.sql`.
3. Ejecutar `Lookups.sql`.
4. Ejecutar `Inserts.sql`.
5. Ejecutar `Programmability.sql`.
6. Ejecutar pruebas de funciones.
7. Ejecutar pruebas de procedimientos.
8. Ejecutar pruebas de triggers.
9. Ejecutar `Queries.sql`.
10. Verificar que los 20 reportes produzcan resultados.
11. Crear una copia de seguridad.
12. Empaquetar los archivos.

# 23. Hacer la revisión final

Antes de comprimir:

1. Ejecutar todos los scripts desde una base de datos limpia.
2. Confirmar que no dependan de datos creados manualmente fuera de los scripts.
3. Confirmar que `Lookups.sql` sea respetado.
4. Confirmar que no haya nombres de tablas o columnas cambiados.
5. Confirmar que los 20 reportes tengan exactamente las columnas solicitadas.
6. Confirmar que los literales coincidan exactamente:
    - `AAA`.
    - `Consolidado`.
    - `Indie`.
    - `Crítico`.
    - `Mixto`.
    - `Divisivo`.
    - `Amigo directo`.
    - `Amigo de un amigo`.
    - `Contacto lejano`.
    - `Contenido restringido por edad`.
7. Confirmar que los errores hagan rollback.
8. Confirmar que no existan datos inválidos.
9. Confirmar que no existan DLC huérfanos.
10. Confirmar que no existan logros huérfanos.
11. Confirmar que no existan relaciones con usuarios inexistentes.
12. Confirmar que no se dupliquen facturas o transacciones.
13. Confirmar que todas las consultas devuelvan resultados útiles.
14. Ejecutar el proyecto completo en un segundo equipo, si es posible.
15. Revisar ortografía y nombres en el informe.
16. Confirmar que todos los integrantes puedan defender el código.

# 24. Crear la entrega final

1. Crear el archivo `DDL.sql`.
2. Crear el archivo `Inserts.sql`.
3. Crear el archivo `Programmability.sql`.
4. Crear el archivo `Queries.sql`.
5. Crear `Informe.pdf` o `Informe.txt`.
6. Incluir `Lookups.sql` si las instrucciones de la materia lo permiten o si es necesario para reproducir la ejecución.
7. Crear el `.rar`.
8. Nombrarlo con este formato:

```
Apellido1Nombre1_Apellido2Nombre2_Apellido3Nombre3.rar
```

1. Abrir el `.rar` y verificar que los archivos estén realmente dentro.
2. Probar que los scripts del `.rar` sean los últimos archivos corregidos.
3. Subir el archivo a Classroom.
4. Confirmar que los demás integrantes marquen la asignación como realizada.

## Orden recomendado de trabajo

Para no intentar resolver todo simultáneamente, el orden más seguro es:

1. DDL completo.
2. Pruebas de PK, FK y `CHECK`.
3. Datos base y lookups.
4. Empresas, productos y juegos.
5. Usuarios, biblioteca y comercio.
6. Descuentos, reembolsos, reseñas y logros.
7. Funciones.
8. Triggers.
9. Procedimientos.
10. Consultas simples.
11. Consultas con agregaciones.
12. Consultas recursivas y división relacional.
13. Pruebas integrales.
14. Informe.
15. Empaquetado final.