# Proyecto Fase 2: Base de datos ConeSTeam

Universidad Central de Venezuela. Facultad de Ciencias. Escuela de Computación.
Asignatura [6303] Bases de Datos. Semestre I-2026.

## Integrantes

| Apellido y nombre | Cédula |
|---|---|
| _(pendiente)_ | _(pendiente)_ |
| _(pendiente)_ | _(pendiente)_ |
| _(pendiente)_ | _(pendiente)_ |

Archivo de entrega: `Apellido1Nombre1_Apellido2Nombre2_Apellido3Nombre3.rar`

## 1. Descripción general

Base de datos en SQL Server (T-SQL) para ConeSTeam, una tienda de distribución digital de videojuegos. Implementa las 28 tablas del modelo relacional definitivo de la Fase 2, la carga de datos de prueba, cinco procedimientos almacenados, cinco funciones, cinco triggers y veinte consultas de reporte.

Base de datos: `ConeSTeamDB`.

## 2. Orden de ejecución

1. `DDL.sql`. Crea la base de datos si no existe, elimina las tablas previas y crea las 28 tablas con sus restricciones.
2. `Inserts.sql`. Carga los datos. Incluye al principio el contenido íntegro de `Lookups.sql` (categorías, idiomas y métodos de pago), sin modificaciones, más las categorías adicionales que pide ese mismo fichero.
3. `Programmability.sql`. Crea funciones, triggers y procedimientos.
4. `Queries.sql`. Ejecuta los 20 reportes.

`Lookups.sql` **no debe ejecutarse por separado**: su contenido ya está en `Inserts.sql` y ejecutarlo dos veces produce un error de clave duplicada.

`Programmability.sql` se ejecuta después de la carga a propósito, para que los triggers no intervengan en la siembra de datos históricos (ver apartado 6.9).

## 3. Tipos de datos

| Uso | Tipo | Justificación |
|---|---|---|
| Identificadores | `INT` | Suficiente para el volumen previsto. `IDENTITY` en las entidades fuertes. |
| Dinero | `DECIMAL(10,2)` | Precisión exacta. `FLOAT` introduce errores de redondeo en importes. |
| Porcentajes | `DECIMAL(5,2)` | Rango 0,00 a 100,00. |
| Horas jugadas, tamaños | `DECIMAL(8,2)` | Admiten fracciones. |
| Fechas sin hora | `DATE` | Nacimiento, registro, lanzamiento, fundación, eventos de descuento, concurrencia. |
| Fechas con hora | `DATETIME2` | Emisión de factura, reembolso, desbloqueo de logro y última sesión, donde importa el momento exacto. |
| Booleanos | `BIT` | Exigido por la consideración D. |
| Códigos de dominio | `VARCHAR` | Valores fijos sin tildes (`'Juego_Base'`, `'AO'`, `'Activa'`...). |
| Textos libres | `NVARCHAR` | Admiten tildes y caracteres de cualquier idioma. |

## 4. Restricciones

### 4.1 Dominio (CHECK)

Se implementan todas las del apartado E del enunciado, más las siguientes:

- No negatividad en todos los campos monetarios (consideración B), en tamaños, horas jugadas, votos y picos de jugadores. El precio 0 está permitido.
- `Descuento_Aplicado_Pct` entre 0 y 100.
- Una empresa no puede ser su propia matriz.
- Un usuario no puede tener una amistad consigo mismo.
- `Subtipo_Jugable` es obligatorio si `Tipo_Contenido = 'Jugable'` y debe ser NULL en caso contrario.

### 4.2 Edad mínima

La consideración C exige usuarios mayores de 13 años. Se implementa con `CHECK (Fecha_Nacimiento <= DATEADD(YEAR, -13, Fecha_Registro))`.

Se compara con `Fecha_Registro` y no con `GETDATE()` porque un CHECK solo se evalúa al insertar o modificar la fila. La edad relevante es la que tenía el usuario al registrarse, y ese dato no cambia con el tiempo.

La restricción de 18 años para contenido M y AO no se resuelve en el DDL, sino en el Trigger 2 en el momento de la compra.

### 4.3 Unicidad

`UNIQUE` en `Usuario.Nickname`, `Usuario.Correo`, `Factura.Codigo_Transaccion`, `Empresa_Corporativa.Nombre`, `Categoria_Oficial.Nombre_Categoria`, `Idioma.Nombre_Idioma`, `Etiqueta_Comunidad.Nombre_Etiqueta` y `Metodo_Pago.Nombre_Metodo`.

**Una reseña por usuario y producto.** `UNIQUE (ID_Usuario, ID_Producto)` en `Resena`. Si el usuario vuelve a reseñar, su reseña anterior se reemplaza, no se duplica. Así ningún usuario infla el recuento de reseñas de un juego (consultas 9 y 10) ni aparece dos veces por el mismo juego (consulta 19). El `UNIQUE` garantiza la regla; el reemplazo lo hace la programabilidad (ver apartado 5).

### 4.4 Claves compuestas

Las entidades débiles por identificación y las tablas de relación usan PK compuesta, según el modelo.

Cuando las columnas de una PK compuesta son a la vez FK hacia la clave de otra tabla, se implementan como una **FK compuesta hacia esa clave**, no como FK sueltas por columna. Así se garantiza que la combinación existe, no solo cada valor por separado:

- `Desbloqueo_Logro(ID_Juego_Base, ID_Logro)` → `Logro(ID_Juego_Base, ID_Logro)`. Impide registrar un logro que no pertenece a ese juego.
- `Suscripcion_Mod(ID_Producto_Base, ID_Mod)` → `Mod(ID_Producto_Base, ID_Mod)`.
- `Reembolso(ID_Factura, ID_Producto)` → `Detalle_Factura(ID_Factura, ID_Producto)`. Ver 4.5.

`DLC.ID_Juego_Base`, `Logro` y `Mod` referencian `Juego_Base`, no `Producto_Digital`, para cumplir la restricción G (un DLC, un logro o un mod dependen de un juego base).

### 4.5 Reembolsos

El modelo marca `ID_Factura` e `ID_Producto` de `Reembolso` como FK, sin indicar la tabla destino. Con dos FK independientes, hacia `Factura` y hacia `Producto_Digital`, se podría reembolsar un producto que no estaba en la factura indicada.

Se resuelve con:

- **FK compuesta** `(ID_Factura, ID_Producto)` → `Detalle_Factura`. Solo se puede reembolsar una línea que existe. La factura y el producto quedan garantizados por las FK de `Detalle_Factura`, así que las FK individuales se eliminan por redundantes. Es el mismo criterio que en `Desbloqueo_Logro`. Como efecto adicional, no se puede borrar una línea de factura que tenga un reembolso.
- **`UNIQUE (ID_Factura, ID_Producto)`**. **No se admiten reembolsos parciales**: una línea se reembolsa completa o no se reembolsa, así que cada línea admite como máximo un reembolso. La PK sigue siendo `ID_Reembolso`, como exige el modelo.

### 4.6 Valores NULL admitidos

- `Empresa_Corporativa.ID_Empresa_Matriz`: empresas raíz o independientes.
- `DLC.Subtipo_Jugable`: DLC no jugables.
- `Producto_Digital.Metacritic_Score`: productos sin nota publicada. En los datos solo ocurre en DLC; todos los juegos base tienen nota. Todo cálculo que usa esta columna aplica `ISNULL(Metacritic_Score, 0)`, porque en SQL cualquier suma con NULL da NULL y el producto quedaría fuera del ranking sin aviso. Se aplica en `fn_calcular_reputacion` y en la consulta 2.
- `Biblioteca.Fecha_Ultima_Sesion`: producto adquirido y nunca jugado. Coherente con el Trigger 3, que inserta con 0 horas y sin sesión.

### 4.7 Relaciones que no se implementan como FK

- **`Desbloqueo_Logro` no tiene FK hacia `Biblioteca`.** El Trigger 4 elimina el producto de la biblioteca al reembolsarlo, y una FK lo bloquearía. Que el usuario posea el juego lo valida `sp_desbloquear_logro`.

## 5. Integridad delegada en la programabilidad

Las reglas siguientes no se fuerzan en el DDL. Se controlan en los procedimientos y triggers, y se ha verificado que los datos sembrados las cumplen:

- Coherencia de la factura: `Monto_Descuento <= Sub_Total` y `Total_Pagado = Sub_Total - Monto_Descuento + Monto_Impuesto`. La controla `sp_realizar_compra`. Las 520 facturas sembradas la cumplen.
- Una amistad no se registra dos veces en sentidos opuestos, (A,B) y (B,A). Las consultas 16 y 20 tratan la relación como bidireccional y eliminan duplicados. Los datos no tienen ningún caso.
- Un producto no puede estar a la vez en `Juego_Base` y en `DLC`, y su subtabla debe coincidir con `Tipo_Producto`. Lo controla `sp_publicar_producto_con_etiquetas`. Forzarlo en el DDL exigiría añadir columnas al modelo, lo que incumple la consideración A.
- Reemplazo de reseña: si el usuario ya reseñó el producto, se actualiza su reseña en lugar de insertar una nueva. _(Pendiente de implementar.)_
- Jerarquías de empresas sin ciclos (A→B→A). El DDL solo impide que una empresa sea su propia matriz. Los datos no tienen ciclos.

## 6. Carga de datos

### 6.1 Datos de catálogo

Las categorías 1 a 16, los idiomas 1 a 10 y los métodos de pago 1 a 7 son idénticos a `Lookups.sql`. Se añaden las categorías 17 a 20 (Supervivencia, Roguelike, Ciencia Ficción, Casual), como exige la cabecera de ese fichero.

### 6.2 Empresas

40 empresas reales, 20 de ellas subsidiarias de cinco matrices (Sony, Microsoft, EA, Ubisoft y Take-Two). La jerarquía tiene hasta tres niveles para que la consulta 18 recorra subsidiarias indirectas:

- Microsoft Gaming → Bethesda Softworks → id Software.
- Take-Two Interactive → 2K Games → Firaxis Games.

Cuatro empresas desarrollan unos juegos y publican otros: Valve, Bethesda Softworks, 2K Games y Team17 (publisher de *Overcooked*, desarrollado por Ghost Town Games).

### 6.3 Productos

Los 210 juegos base son títulos reales, todos desarrollados por alguna de las 40 empresas cargadas y con su publisher real. Cuando el publisher original no está entre las 40 empresas, el juego no se incluye.

Criterios de los datos de cada juego:

- **Fecha de lanzamiento:** la del lanzamiento original. Siempre es anterior a cualquier venta, reseña, descuento o registro de concurrencia del producto.
- **Clasificación:** la ESRB real. E10+ se carga como `E`, porque el dominio del enunciado no la incluye.
- **Categorías:** el género real del juego, de 2 a 3 categorías oficiales por título. Las 20 categorías tienen al menos un producto.
- **Precio:** el catálogo tiene cuatro tramos (gratuito, 19,99, 39,99 y 59,99 USD), asignados por antigüedad. No es el precio de venta real de cada título, y se mantiene para conservar la coherencia con las facturas y los descuentos ya sembrados.
- **Descripciones:** la corta indica el género y la larga resume la premisa real del juego.
- **Metacritic, tamaño y motor gráfico:** valores aproximados a los reales, a efectos de simulación.
- **Gratuitos:** 13 juegos free-to-play reales (Counter-Strike 2, Dota 2, Team Fortress 2, Apex Legends, Los Sims 4...).

Los 90 DLC también son contenidos reales de su juego base: expansiones, pases de temporada, packs cosméticos y bandas sonoras oficiales. Su clasificación de edad es la de su juego base. Su fecha es la de lanzamiento real y nunca es anterior a la del juego base. El tamaño es una estimación según el tipo de contenido. Los 22 DLC gratuitos se mantienen; en algunos casos son contenidos que en la realidad fueron de pago, y su precio de catálogo se conserva por coherencia con las facturas.

### 6.4 Requisitos del sistema

Cada juego base tiene sus dos perfiles (`Minimo` y `Recomendado`) con los requisitos reales publicados:

- **Juegos de PC en Steam (179):** requisitos oficiales de su ficha en la tienda de Steam, obtenidos de su API pública en octubre de 2026. Cuando un juego aparece en Steam con otra edición (*Complete Edition*, *Remastered*, *Definitive Edition*), se toman los de esa edición.
- **Juegos de PC fuera de Steam (8):** *Counter-Strike: Global Offensive*, *Forza Horizon 3*, *Anthem*, *SimCity*, *Titanfall*, *Los Sims*, *Los Sims 2* y *Grand Theft Auto 2*. Requisitos de PCGamingWiki, que recoge los oficiales del editor.
- **Juegos sin versión de PC (23):** exclusivos de Nintendo, de PlayStation y de consolas portátiles. El perfil recoge el hardware real de la consola para la que salió el juego. *Gran Turismo 7*, que salió a la vez en PS4 y PS5, tiene PS4 como mínimo y PS5 como recomendado.
- **Perfil que falta:** si el editor solo publica requisitos mínimos, el perfil recomendado copia los mínimos. Ocurre en 61 juegos, incluidos los de consola.
- **macOS:** en los 34 juegos compatibles con Mac, el sistema operativo indica también la versión mínima de macOS (por ejemplo, `Windows 10 64 bits / macOS 14.7.1 o posterior`).
- Los textos se han traducido al español y condensado cuando superaban el tamaño de la columna, sin perder el dato técnico.

**Idiomas.** `Soporte_Idioma` recoge, de los 10 idiomas de `Lookups.sql`, los que cada juego admite oficialmente:

- **Steam (179 juegos):** la tienda indica los idiomas de cada juego y marca los que tienen audio. La API no separa interfaz y subtítulos, así que ambos se cargan a 1 y el audio solo cuando Steam lo indica.
- **PCGamingWiki (9 juegos):** distingue interfaz, audio y subtítulos. Se usa para los juegos fuera de Steam y para *GTA: San Andreas*, cuya ficha de Steam solo lista el inglés aunque el juego tiene traducción oficial a cinco idiomas más. Las traducciones de aficionados no se cuentan.
- **Consolas (23 juegos):** localización habitual de cada plataforma. Es un dato aproximado, no contrastado título a título.
- Las variantes de un idioma se agrupan: español de España e Hispanoamérica, portugués de Portugal y Brasil, chino simplificado y tradicional.

**Logros.** Cada juego base tiene entre 8 y 10 logros (el enunciado pide de 5 a 30):

- **144 juegos con logros oficiales de Steam:** nombre y descripción oficiales en español, y su marca de oculto (`Es_Secreto`). De cada juego se toman 10 logros del juego base (sin los de sus DLC), repartidos uniformemente por porcentaje global de desbloqueo, de los más comunes a los más raros. El `ID_Logro` sigue ese orden. Fuente: página pública de logros de Steam Community y API de porcentajes globales de Steam, consultadas en octubre de 2026.
- **66 juegos con hitos de la partida:** juegos de consola, versiones de Steam sin logros (ediciones antiguas cuyos logros estaban en otras plataformas) y juegos de PC fuera de Steam. Tienen 8 hitos reales de su historia o de su modo de juego, con los desenlaces marcados como ocultos. **No son los nombres oficiales de los trofeos o logros**, que no se han podido consultar porque las webs que los recogen bloquean el acceso automatizado.

**Etiquetas de la comunidad.** Las 50 etiquetas de `Etiqueta_Comunidad` se asocian a los 210 juegos base, con entre 2 y 6 etiquetas por juego (998 filas):

- **Juegos de Steam (179):** etiquetas de la comunidad de Steam traducidas a las 50 del catálogo. Se toman las 5 más votadas que tienen equivalente, y `Cantidad_Votos` es el **número real de votos** de cada etiqueta en Steam (octubre de 2026). *Mundo submarino* se añade como sexta etiqueta en los dos juegos que la tienen en Steam.
- **Juegos fuera de Steam (31):** 3 a 5 etiquetas asignadas según su género, con votos **estimados** en proporción a juegos de Steam de popularidad parecida.
- Dos etiquetas del catálogo se renombran, conservando su ID, porque ningún juego encajaba con ellas: *Simulación médica* pasa a *Simulación de conducción* y *Bullet Hell* pasa a *Lucha*. Así las 50 etiquetas quedan asociadas al menos a un producto.

**Galería multimedia.** 250 de los 300 productos (83%) tienen entre 2 y 7 archivos (1.415 en total). Las URLs siguen la convención de la red de distribución propia de la tienda, `https://cdn.conesteam.com/media/<ID_Producto>/<título>/screenshot_NN.jpg` o `trailer_NN.mp4`. En los juegos de Steam, el número de capturas (hasta 5) y de tráileres (hasta 2) corresponde al que el juego tiene realmente en su ficha de Steam. Las URLs son ficticias, porque ConeSTeam es una tienda simulada.

**Mods.** 61 mods reales y conocidos de la comunidad, repartidos entre 28 juegos de PC muy modificables (*Skyrim*, *Fallout*, *GTA*, *Terraria*, *XCOM*, *Civilization*, *Los Sims*...). Los tamaños son aproximados. Los juegos de consola no tienen mods porque esas plataformas no los admiten.

**Suscripciones a mods.** 188 suscripciones de 77 usuarios. Solo se suscribe quien tiene el juego del mod en su biblioteca, siempre después de comprarlo. Alrededor de un 38% de los dueños de cada juego modificable usa entre 1 y 3 mods, y los mods base (extensores de scripts, cargadores, parches comunitarios) son los más suscritos. Los 6 usuarios de la consulta 15 están suscritos a algún mod de *Los Sims 4*.

### 6.5 Usuarios

- **251 usuarios.** 250 tienen apodos ficticios de jugador (por ejemplo `GlitchMoth` o `Velvet_Mantis2003`) y el 251 (`znwb`) es el de un integrante del grupo. No se usan nombres de otras personas reales. El correo se deriva del apodo y conserva el reparto de dominios (gmail, hotmail, outlook, yahoo.es, icloud y live) que usa la consulta 3.
- **Fecha de registro:** repartida entre el 20-10-2024 y el 15-10-2026, y siempre anterior a la primera actividad del usuario (compras, reseñas, deseos, carrito, suscripciones, logros y amistades). Las amistades son posteriores al registro de ambos usuarios.
- **Contraseñas:** `Contrasena_Hash` guarda un SHA-256 de 64 caracteres hexadecimales calculado sobre un texto ficticio. Ningún hash corresponde a una contraseña real.
- **Edades:** todos los usuarios tenían al menos 13 años al registrarse (restricción `CK_Usuario_Edad`). Hay **15 menores de edad** (14 a 16 años) para probar el Trigger 2: IDs 2, 8, 9, 11, 14, 78, 80, 101, 104, 123, 141, 161, 177, 179 y 188. Ninguno tiene productos M o AO en compras, biblioteca ni carrito.
- **Generaciones** (consulta 8): 89 Gen Z, 112 millennials y 50 Gen X o anteriores.
- **Estado de cuenta:** 221 activas, 18 suspendidas y 12 baneadas (12%).

**Amistades.** 320 relaciones con los tres estados: 217 aceptadas, 63 bloqueadas y 40 pendientes. No hay autoamistades ni pares repetidos en sentido inverso. Al pasar amistades a pendiente se han protegido las de los usuarios que tienen *Overcooked*, para no vaciar la consulta 16.

### 6.6 Facturas

- **Fechas fijas** entre el 20-10-2024 y el 19-10-2026 (los dos años anteriores a la fecha de generación de los datos). Los reportes del mes actual (consultas 1, 14 y 18) devuelven datos si se ejecutan en octubre de 2026. **Si la defensa es en otro mes, hay que regenerar las fechas.**
- Ninguna factura es anterior al lanzamiento de los productos que contiene.
- La hora de emisión varía a lo largo del día, con más compras por la tarde y la noche.
- `Codigo_Transaccion` sigue un único formato: `TRX-AAAAMMDD-NNNN` (fecha de emisión e ID de factura).
- **Consulta 4 (recompra temprana):** en 15 usuarios la segunda compra se produce entre 2 y 28 días después de la primera.

**Detalle de las facturas.** El contenido de las 521 facturas se ha regenerado (1.164 líneas, de 1 a 5 por factura) conservando su fecha, usuario y método de pago. Reglas:

- Ningún usuario compra dos veces el mismo producto, ni un producto antes de su lanzamiento.
- Los menores de edad no compran productos M ni AO.
- Un DLC solo se compra si el usuario ya tiene el juego base o lo compra en la misma factura.
- `Precio_Venta_Historico` es el precio efectivo, el mismo que devolvería `fn_precio_con_descuento`: con rebaja vigente, `Precio_Base_En_Evento` menos el porcentaje (`Descuento_Aplicado_Pct`); sin rebaja, el precio de catálogo con un 0%.
- La popularidad de cada juego sigue los votos de Steam.
- **Fórmula de la cabecera:** `Sub_Total` = suma de los precios de referencia; `Monto_Descuento` = `Sub_Total` menos la suma de las líneas; `Monto_Impuesto` = 16% de (`Sub_Total` − `Monto_Descuento`), redondeado a 2 decimales; `Total_Pagado` = `Sub_Total` − `Monto_Descuento` + `Monto_Impuesto`.
- Datos garantizados para las consultas: 6 usuarios con *Los Sims 4* y al menos 5 de sus DLC (consulta 15), 4 grupos de amigos con *Overcooked* (consulta 16), *Elden Ring*, *Baldur's Gate 3* y *Cyberpunk 2077* con más de 50 ventas sin descuento (consulta 17), y ventas de 9 estudios en el mes actual (consultas 1, 14 y 18).
- La factura 521 es la licencia gratuita de *Counter-Strike 2* del usuario 251, por 0,00 USD.

**Biblioteca.** Contiene exactamente los productos comprados y no reembolsados de cada usuario (1.128 filas), que es lo que harían el Trigger 3 al comprar y el Trigger 4 al reembolsar.

- Horas jugadas variadas según el género: más en multijugador, mundo abierto, rol y estrategia, y menos en puzles y plataformas. Un 8% de los juegos está sin jugar (0 horas y sin última sesión).
- Los DLC no acumulan horas propias, porque se juegan dentro de su juego base (0 horas, sin última sesión).
- La última sesión es siempre posterior a la compra y anterior a la fecha de generación.
- Hay 9 compras de los últimos 14 días con menos de 2 horas jugadas, para probar un reembolso válido con `sp_procesar_reembolso`.

**Carritos y listas de deseos.** Ningún usuario tiene en el carrito o en la lista de deseos un producto que ya posee, ningún DLC está en un carrito sin su juego base (en la biblioteca o en el mismo carrito), y ningún menor tiene productos M en su lista de deseos. Los 10 carritos (17 productos, agregados en los últimos 20 días) son escenarios de prueba de `sp_realizar_compra` y de los triggers:

| Usuario | Escenario | Resultado esperado |
|---|---|---|
| 3, 34, 36, 88, 91, 199 | Compra normal de 1 a 3 juegos | Factura creada y carrito vaciado |
| 94 | DLC cuyo juego base ya está en la biblioteca | Compra válida |
| 16 | Juego base y su DLC en el mismo carrito | Compra válida |
| 177 (menor) | Un juego M y uno T | El Trigger 2 rechaza la compra con "Contenido restringido por edad" y se deshace toda la transacción |
| 78 (menor) | Dos juegos E | Compra válida |

Las 53 entradas de lista de deseos pertenecen a 20 usuarios, con fechas desde enero de 2025 y la notificación de descuento activada en 32.

**Reembolsos.** 36 reembolsos (31 de juegos base y 5 de DLC), todos de productos de pago:

- Cada reembolso devuelve el importe íntegro pagado por su línea de factura, y se produce entre 1 y 14 días después de la compra, como exige `sp_procesar_reembolso`.
- Cuando se reembolsa un juego base, se reembolsan también los DLC de ese juego que el usuario compró en la misma factura, para que nadie conserve un DLC sin su juego.
- Hay 5 reembolsos en el mes actual y 2 en el anterior, para las consultas 6, 14 y 18.
- No se reembolsan *Elden Ring*, *Baldur's Gate 3*, *Cyberpunk 2077* (consulta 17), *Los Sims 4* ni sus DLC (consulta 15), *Overcooked* (consulta 16) ni el *Counter-Strike 2* del usuario 251.

**Reseñas.** 936 reseñas (una como máximo por usuario y producto) sobre 205 productos:

- **Jugadores (505 reseñas):** solo reseñan productos de su biblioteca que han jugado, después de comprarlos. Ningún menor reseña juegos M.
- **Críticos especializados (431 reseñas, `Es_Critica_Especializada = 1`):** 20 usuarios adultos que reseñan juegos sin haberlos comprado, como ocurre con las copias de prensa que reciben los medios. Sus notas tienen menos dispersión.
- **Notas:** la nota media de cada juego se aproxima a su Metacritic dividido entre 10. La media de la plataforma es de 8,12.
- **Consulta 9:** seis juegos polémicos con al menos 20 reseñas y nota media por debajo de la de la plataforma, dos por cada veredicto: *Crítico* (*Fallout 76* y *Anthem*), *Mixto* (*Battlefield 2042* y *Ghost Recon Breakpoint*) y *Divisivo* (*Mafia III* y *Resident Evil 6*).
- **Consulta 10:** *Elden Ring*, *Baldur's Gate 3* y *Team Fortress 2* cumplen las cuatro condiciones. *Counter-Strike 2* también, si la media del estudio se calcula como media de las medias de cada juego.
- **Consulta 11:** 12 usuarios con biblioteca no publican reseñas (IDs 3, 18, 20, 23, 24, 35, 50, 51, 56, 57, 65 y 66).
- Los textos se generan a partir de los aspectos propios del género del juego y de la nota, en español y con frases distintas para jugadores y críticos.

**Logros desbloqueados.** 2.768 desbloqueos de 110 usuarios en 176 juegos:

- Solo desbloquea logros quien tiene el juego base en su biblioteca y lo ha jugado. Las fechas quedan entre la compra y la última sesión.
- La probabilidad de cada logro sigue su porcentaje global real en Steam (o una curva decreciente en los hitos), ajustada por las horas jugadas. Los logros más comunes se desbloquean antes.
- **Consulta 11:** los 12 usuarios sin reseñas tampoco tienen logros desbloqueados.
- **Consulta 13:** 9 usuarios han desbloqueado todos los logros de un juego (por ejemplo, el 190 en *Baldur's Gate 3* y el 175 en *Grand Theft Auto V*).
- **Consulta 19:** 32 reseñas con nota menor que 4 de usuarios con menos del 10% de los logros del juego. 29 son de críticos especializados, que reseñan sin haber jugado en la plataforma, y 3 de jugadores que dejaron el juego sin avanzar.

### 6.7 Descuentos

- **13 eventos con nombre** entre octubre de 2024 y octubre de 2026, en fechas aproximadas a las rebajas reales de Steam: *Halloween Sale*, *Autumn Sale*, *Winter Fest*, *Spring Sale* y *Summer Sale* de cada año, más tres fines de semana de editor (Ubisoft 2025, Capcom 2026 y Bandai Namco 2026, este último en el mes actual).
- 510 rebajas para 112 productos (65 juegos base y 15 DLC elegidos por popularidad, más los juegos de cada editor en su fin de semana). Las rebajas grandes (invierno y verano) incluyen a más productos que las de temporada.
- Porcentajes del 10% al 75%, mayores cuanto más barato o antiguo es el producto. Ningún producto tiene dos rebajas solapadas, así que `fn_precio_con_descuento` nunca encuentra dos descuentos vigentes a la vez para la misma fecha.
- Ninguna rebaja empieza antes del lanzamiento del producto.
- `Precio_Base_En_Evento` coincide con el precio actual, porque los datos no simulan cambios de precio. La columna está preparada para conservar el precio de referencia si el precio base cambia después.

**Concurrencia.** Serie mensual de picos de jugadores simultáneos para los 60 productos más populares (1.405 registros, de noviembre de 2024 a octubre de 2026, entre 14 y 24 meses por producto). El valor de referencia es el número real de jugadores conectados en Steam en octubre de 2026, consultado con la API pública `GetNumberOfCurrentPlayers`. Hacia atrás, la serie se simula con variación mensual, subidas en diciembre, enero y julio, durante las rebajas del propio juego y tras el lanzamiento de los juegos recientes. Los meses anteriores al lanzamiento no tienen registro.

### 6.8 Volumen

| Requisito del enunciado | Mínimo | Cargado |
|---|---|---|
| Empresas (con matriz) | 40 (8) | 40 (20) |
| Productos (juegos base / DLC) | 300 (~70/30) | 300 (210 / 90) |
| Productos M o AO | 15 | 119 |
| DLC gratuitos | 20 | 22 |
| Perfiles de requisitos por juego base | 2 | 2 |
| Idiomas por juego base | 2 | 2 a 10 |
| Logros por juego base | 5 a 30 | 8 a 10 |
| Etiquetas distintas asociadas | 50 | 50 |
| Productos con 2+ archivos multimedia | 80% | 83% |
| Usuarios (suspendidos o baneados) | 250 (10%) | 251 (12%) |
| Amistades (estados) | 300 (mezcla) | 320 (3 estados) |
| Facturas (productos por factura) | 500 (1 a 5) | 521 (1 a 5) |
| Productos con concurrencia | 50 | 60 |
| Reembolsos | 30 | 36 |
| Reseñas | 800 | 936 |
| Coleccionistas completos | al menos 1 | 9 |

### 6.9 Coherencia sin triggers (verificada)

Como los triggers se crean después de la carga, la coherencia que garantizarían se ha sembrado a mano:

- Todo producto facturado está en la biblioteca del comprador.
- Ningún producto reembolsado sigue en la biblioteca.
- Ningún menor de 18 años compra productos M o AO.
- Ningún DLC está en un carrito sin su juego base en la biblioteca o en el mismo carrito.
- Ningún logro está desbloqueado sin el juego en la biblioteca.

Todas estas reglas se han comprobado sobre los datos finales de `Inserts.sql`.

## 7. Limitaciones conocidas

- Los triggers y procedimientos solo protegen las operaciones que pasan por ellos. Un `INSERT` directo puede saltarse las reglas del apartado 5.
- No se crean índices sobre las columnas FK; SQL Server no los crea automáticamente. Con el volumen del proyecto no afecta, pero en producción sería la primera mejora de rendimiento.

## 8. Uso de inteligencia artificial

Siguiendo lo permitido por el enunciado, se usó IA para generar datos de prueba y para revisar el código. La revisión del DDL, el contraste con los datos y la redacción de este informe se hicieron con asistencia de Claude (Anthropic). Todo el código ha sido revisado por los integrantes, que pueden explicarlo en la defensa.

---

## Pendientes del informe (borrar antes de entregar)

- [ ] Implementar el reemplazo de reseña (procedimiento o trigger).
- [ ] Aplicar `ISNULL(Metacritic_Score, 0)` en la consulta 2 cuando llegue `Queries.sql`.
- [ ] Revisar que `fn_precio_con_descuento` sea coherente con el criterio de no solapar rebajas.
- [ ] Documentar el tipo de trigger elegido para la protección de menores ("antes de insertar").
- [ ] Explicar funciones, triggers, procedimientos y consultas complejas.
- [ ] Añadir evidencias de ejecución.
