# Práctica 2 SQL — Sistema de Biblioteca Itinerante (Bibliobús)

Fundamentos de Sistemas de Bases de Datos — UC3M

## Descripción

Modelado y explotación en **Oracle SQL** de la base de datos de un sistema de **biblioteca itinerante (bibliobús)**: gestión de libros y ediciones, flota de autobuses y conductores, rutas y paradas, usuarios, préstamos/reservas y publicaciones (posts) de los usuarios.

El proyecto incluye:

- El **esquema relacional** completo (creación de tablas con sus restricciones).
- La **carga de datos** de prueba.
- **Consultas SQL avanzadas** (subconsultas, `INTERSECT`, funciones de fecha, agregaciones).
- **Vistas** para simplificar el acceso a los datos más consultados.
- Un **paquete PL/SQL** (`foundicu`) con la lógica de negocio de los préstamos.
- **Triggers** para reglas de negocio (impedir posts institucionales, marcar fecha de baja de ejemplares deteriorados, contar lecturas...) y sus correspondientes pruebas.

## Modelo de datos

Entidades principales del esquema (`NEW_creation.sql`):

- **Catálogo**: `books`, `more_authors`, `editions`, `copies`
- **Flota y rutas**: `municipalities`, `routes`, `drivers`, `bibuses`, `assign_drv`, `assign_bus`, `stops`, `services`
- **Usuarios y actividad**: `users`, `loans`, `posts`

## Estructura del repositorio

| Fichero | Descripción |
|---|---|
| `NEW_creation.sql` | Creación (y destrucción previa) de todas las tablas del esquema. |
| `NEW_load.sql` | Carga de datos de ejemplo respetando el orden de dependencias entre tablas. |
| `consultas.sql` | Batería de consultas SQL sobre el esquema (subconsultas, `INTERSECT`, agregaciones, funciones de fecha...). |
| `vista.sql` | Inserts adicionales de prueba y definición de las vistas `my_data`, `my_loans` y `my_reservations`. |
| `paqueton.sql` | Paquete PL/SQL `foundicu` con la lógica de gestión de préstamos y reservas (límite de préstamos activos, conversión de reserva a préstamo, etc.). |
| `triggers.sql` | Triggers de negocio: restricción de posts institucionales, marcado de copias deterioradas, contador de lecturas por libro, entre otros. |
| `Pruebas_triggers.sql` | Casos de prueba (inserts/updates) para verificar el comportamiento de los triggers. |

## Cómo ejecutarlo

Pensado para una base de datos **Oracle** (usa tipos y funciones específicas como `VARCHAR2`, `SYSDATE`, `RAISE_APPLICATION_ERROR`, paquetes PL/SQL).

```sql
-- 1. Crear el esquema
@NEW_creation.sql

-- 2. Cargar los datos de ejemplo
@NEW_load.sql

-- 3. Crear vistas y datos adicionales
@vista.sql

-- 4. Crear el paquete de negocio
@paqueton.sql

-- 5. Crear los triggers
@triggers.sql

-- 6. (Opcional) Probar triggers y lanzar las consultas
@Pruebas_triggers.sql
@consultas.sql
```

## Tecnologías

- Oracle SQL / PL/SQL (tablas, vistas, triggers, paquetes)
