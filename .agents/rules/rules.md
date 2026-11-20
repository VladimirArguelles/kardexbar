# Estándares de arquitectura — KardexBar

## Organización

- `lib/core/`: configuración compartida, tema y widgets/utilidades realmente reutilizables; no alojar lógica particular de una funcionalidad.
- `lib/features/<funcionalidad>/`: módulos de dominio, preferentemente con `models/`, `services/` y `screens/` según el patrón presente.
- `lib/main.dart`: composición de la aplicación y navegación de nivel superior; evitar convertirlo en contenedor de lógica de negocio.
- `test/`: pruebas Flutter. Mantén las pruebas cerca de los comportamientos existentes y evita depender de credenciales o servicios remotos.
- `supabase/migrations/`: cambios de esquema versionados, incrementales y coherentes con el estado real de Supabase. No edites una migración ya aplicada como si fuese una actualización desplegable; crea otra cuando corresponda.

No muevas archivos ni crees capas nuevas solo para uniformidad. Antes de decidir, inspecciona el módulo y conserva compatibilidad con sus consumidores.

## Capas y responsabilidades

- **UI (`screens/`, `widgets/`)**: presentación, interacción, validación de entrada y estados de carga/error. No debe implementar escrituras de inventario directas ni contener SQL.
- **Modelos (`models/`)**: representación y conversión tipada de datos. Los nombres JSON deben corresponder al contrato real de la API/esquema.
- **Servicios (`services/`)**: acceso a Supabase, lecturas y llamadas RPC. Mantén errores observables y propágalos o preséntalos siguiendo el patrón de la funcionalidad.
- **Core**: componentes transversales sin dependencia circular de `features/`.
- **PostgreSQL/RPC**: fuente de verdad para reglas transaccionales y mutaciones de stock. La función debe validar entradas, operar sobre las tablas confirmadas y escribir el kardex atómicamente.

Evita dependencias circulares entre funcionalidades. Extrae una abstracción compartida únicamente cuando exista más de un consumidor y una semántica común clara.

## Convenciones de código

- Dart con formato `dart format`; respeta `analysis_options.yaml` y los lints activos.
- Archivos y carpetas Dart en `snake_case`; tipos/clases en `UpperCamelCase`; miembros y variables en `lowerCamelCase`.
- Usa tipos explícitos y conversiones seguras en límites JSON. Evita `dynamic`, casts inseguros y valores por defecto que oculten datos inválidos.
- Mantén widgets pequeños y estado local donde sea suficiente. Usa Riverpod solo conforme al uso real del repositorio; no añadas providers ni dependencias sin necesidad.
- Errores de red, RPC y parseo deben ser visibles y accionables; no los silencies con `catch` vacío ni devuelvas éxitos ficticios.
- Evita comentarios que repitan el código. Documenta únicamente contratos o lógica no obvia.

## SQL, contratos y datos

- Los nombres y tipos SQL deben coincidir entre migración, RPC, servicio y modelo.
- Para invocaciones Supabase, verifica nombres y parámetros de RPC; los nombres de argumentos son parte del contrato.
- Las migraciones deben ser seguras para el estado objetivo, explícitas y revisables. No elimines o renombres tablas/columnas usadas sin migración de transición y actualización de consumidores.
- Protege tablas con RLS y políticas de mínimo privilegio. No agregues acceso `anon` abierto ni `SECURITY DEFINER` sin necesidad demostrada, `search_path` seguro y revisión de permisos.
- No permitas stock negativo bajo errores o concurrencia; movimientos de stock y kardex deben confirmarse o revertirse juntos.

## Interfaz

- Usa `AppTheme` y componentes existentes antes de crear colores/estilos paralelos.
- Preserva accesibilidad, contraste, adaptación móvil/web y objetivos táctiles del diseño existente.
- Los estados vacíos, de carga y error deben distinguirse; las acciones de escritura deben bloquear duplicados mientras están en curso y comunicar el resultado.

## Cambios generados

- `docs/` es una salida web compilada versionada; no edites manualmente `main.dart.js` ni manifiestos generados.
- Revisa los cambios del build y no incluyas ruido ni artefactos no relacionados.
- No cambies la versión de `pubspec.yaml`, plataformas, configuración de publicación ni secretos sin requerimiento explícito.
