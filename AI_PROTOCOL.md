# Protocolo de Desarrollo e Inteligencia Artificial para KardexBar
> Instrucción para la IA: al abrir este documento, adopta de inmediato el rol de Arquitecto de Software Senior y Líder Técnico experto en Flutter (Dart) y Supabase (PostgreSQL) para el proyecto **KardexBar**. Debes razonar con precisión, verificar fuentes de verdad reales y ajustar todo lo que hagas al contexto técnico y operativo de este sistema de control de barra, comandas e inventario kardex.

---

## 1. Objetivo del Proyecto y Contexto Operativo
**KardexBar** es una aplicación multiplataforma (Móvil/Web) de alto rendimiento desarrollada en Flutter y Supabase, optimizada para la operación física y el control integral de barra e inventario en tiempo real.

### 1.1. Contexto Operativo Central
- **Operación de un solo Bartender en la Sede Principal:** La interfaz y los flujos de trabajo están diseñados para la agilidad de un único operador/bartender que atiende comandas, despacha tragos, registra mermas y gestiona el stock físico directo de la barra.
- **Trazabilidad Inter-Sede:** El sistema gestiona inventario tanto en la **Sede Principal** (sede operativa activa por defecto) como en la **Sede Secundaria** (sede de respaldo/almacén secundario), permitiendo registrar traslados bidireccionales inmediatos y auditoría estricta de bolsas de hielo.
- **Control Especializado de Hielo:** Panel dual dedicado para supervisar y registrar entradas, traslados y mermas por deshielo de bolsas de hielo entre ambas sedes.
- **Consumo Interno Diferenciado:** Trazabilidad separada de cortesías y consumos entre **Dueño** y **Trabajadores** para evitar descuadres en el inventario de botellas e insumos.

---

## 2. Regla Estricta de Integridad Transaccional (ACID)
> [!IMPORTANT]
> **REGLA DE ORO DE INTEGRIDAD EN STOCK:**
> Todo descuento o movimiento de stock por **comandas, recetas/escandallos, traslados entre sedes, mermas, entradas de compras o consumo interno** DEBE ejecutarse mediante **Funciones RPC atómicas en PostgreSQL** dentro de una única transacción en base de datos.
> 
> **Queda estrictamente prohibido** calcular o descontar stock mediante múltiples llamadas secuenciales desde el cliente Dart (`supabase.from(...).update(...)`). Todo cálculo de inventario debe resolverse en el motor de base de datos para garantizar consistencia atómica total contra caídas de red o fallas de concurrencia.

---

## 3. Stack Tecnológico y Arquitectura Flutter (Feature-First)

### 3.1. Stack
- **Frontend:** Flutter (Dart 3.x) con arquitectura **Feature-First**.
- **Gestión de Estado y Reactividad:** Flutter Riverpod / Stateful & ValueNotifiers según granularidad.
- **Backend & Base de Datos:** Supabase (PostgreSQL 15+, PL/pgSQL RPCs Atómicas, RLS, Auth).
- **Impresión y Exportación:** Paquetes `pdf` y `printing` para tickets POS/térmicos, reportes PDF y exportaciones tabulares Excel/CSV con BOM UTF-8.
- **Despliegue Web:** Web estática compilada en `docs/` con `--base-href="/kardexbar/"` para GitHub Pages.

### 3.2. Estructura de Directorios Oficial (`lib/`)
El proyecto se organiza estrictamente bajo el patrón **Feature-First**:

```text
lib/
├── core/
│   ├── config/
│   │   └── supabase_config.dart       # Inicialización de Supabase y constantes de Sede Principal fija
│   ├── theme/
│   │   └── app_theme.dart             # Tema oscuro de alto contraste optimizado para entornos de barra
│   └── widgets/
│       └── export_print_widget.dart   # Widget reutilizable para Imprimir (PDF/POS) y Compartir Excel (.csv/.xlsx)
├── features/
│   ├── auth/                          # Acceso rápido de Bartender único (Sede Principal fija)
│   ├── comandas/
│   │   ├── models/                    # Modelos Comanda, ComandaDetalle y ProductoBarra
│   │   ├── services/                  # Integración con RPC registrar_comanda_completa y consultas
│   │   └── screens/
│   │       ├── nueva_comanda_screen.dart      # Formulario táctil: Fecha, Cliente, Productos, Cantidad y Total auto-calculado
│   │       └── historial_comandas_screen.dart # Historial con DOBLE BUSCADOR: Filtro 1 (Cliente) + Filtro 2 (Producto)
│   ├── inventario/
│   │   ├── models/                    # Modelos InsumoInventario y KardexMovimiento
│   │   ├── services/                  # Servicios de stock y llamadas a RPCs de inventario
│   │   └── screens/
│   │       ├── stock_vivo_screen.dart         # Stock Sede Principal con alertas visuales de nivel
│   │       ├── entradas_screen.dart           # Registro de compras y recepción de insumos
│   │       ├── traslados_screen.dart          # Traslados entre Sede Principal y Sede Secundaria
│   │       └── mermas_screen.dart             # Registro de pérdidas, roturas y descarte
│   ├── hielo/
│   │   └── screens/
│   │       └── control_hielo_screen.dart      # Panel dual de bolsas de hielo (Sede Principal y Secundaria) + compras/mermas
│   ├── consumo_interno/
│   │   └── screens/
│   │       └── consumo_interno_screen.dart    # Registro diferenciado: Dueño vs Trabajadores
│   └── cierre_reportes/
│       └── screens/
│           └── cierre_turno_screen.dart       # Cuadre diario del turno del Bartender + integración de ExportPrintWidget
└── main.dart
```

---

## 4. Esquema de Base de Datos y Contratos SQL (Supabase)

### 4.1. Tablas Principales
1. `sedes`: Identificadores de sedes (`id`, `nombre`: 'Sede Principal', 'Sede Secundaria', `es_principal`).
2. `productos_barra`: Catálogo de venta de la barra (`id`, `nombre`, `categoria`: 'Cervezas', 'Licores', 'Cocteles', 'Jugos', 'No Alcoholicas', `precio_venta`, `es_receta`, `activo`).
3. `insumos_inventario`: Stock físico de insumos por sede (`id`, `sede_id` FK, `nombre`, `unidad_medida`: 'unidad', 'caja', 'ml', 'gr', 'bolsa_hielo', `stock_actual`, `stock_minimo`, `costo_unitario`).
4. `recetas_escandallo`: Receta de preparación por producto (`id`, `producto_barra_id` FK, `insumo_id` FK, `cantidad_requerida`).
5. `comandas`: Encabezado de comanda despachada (`id`, `fecha`, `nombre_cliente`, `sede_id` FK, `precio_total`, `notas`).
6. `comanda_detalles`: Renglones de la comanda (`id`, `comanda_id` FK ON DELETE CASCADE, `producto_barra_id` FK, `nombre_producto`, `cantidad`, `precio_unitario`, `subtotal` GENERATED ALWAYS AS (cantidad * precio_unitario) STORED).
7. `kardex_movimientos`: Libro mayor de movimientos físicos (`id`, `fecha`, `insumo_id` FK, `sede_origen_id` FK, `sede_destino_id` FK nullable, `tipo_movimiento`: 'ENTRADA_COMPRA', 'VENTA_COMANDA', 'TRASLADO', 'MERMA', 'CONSUMO_DUENO', 'CONSUMO_TRABAJADOR', `cantidad`, `beneficiario_o_motivo`, `referencia_id`).

### 4.2. Funciones RPC Atómicas Obligatorias
- `registrar_comanda_completa(p_fecha, p_nombre_cliente, p_sede_id, p_items_json, p_notas)`:
  Inserta cabecera y detalles, calcula `precio_total` real, descuenta el stock en `insumos_inventario` (descuento directo por unidad o desglosado mediante `recetas_escandallo`) y registra cada salida física en `kardex_movimientos` dentro de una transacción atómica.
- `registrar_traslado_sedes(p_insumo_nombre, p_sede_origen_id, p_sede_destino_id, p_cantidad, p_motivo)`:
  Resta stock en la sede de origen, suma en la sede de destino y registra el movimiento de kardex en una sola operación atómica.
- `registrar_merma(...)`: Descuenta stock y asienta la pérdida en Kardex.
- `registrar_consumo_interno(...)`: Descuenta stock y asienta si fue consumo del Dueño o de Trabajadores.
- `registrar_entrada_compra(...)`: Incrementa stock y registra el costo y proveedor en Kardex.
- `registrar_movimiento_hielo(...)`: Gestiona movimientos específicos de bolsas de hielo entre sedes.

### 4.3. Seguridad y RLS
- `ROW LEVEL SECURITY (RLS)` habilitado en el 100% de las tablas.
- Políticas para usuarios autenticados (`authenticated`) con permisos completos de operación.

---

## 5. Diseño Visual e Interfaz de Usuario
- **Entorno de Barra:** La barra presenta baja iluminación y alta velocidad de operación. La UI debe emplear un tema oscuro de **alto contraste**:
  - Fondo Canvas / Superficie: Carbón Antracita / Azul Marino Profundo (`#00162B` / `#02283F` / `#161922`).
  - Acentos de Acción: Ámbar Oro (`#FFB703`), Naranja Vibrante (`#FB8500`) y Cian Neón (`#27A0D7`).
  - Alertas Semánticas: Verde esmeralda (stock óptimo), Ámbar brillante (stock mínimo / alerta), Rojo carmesí neón (stock crítico / merma / agotado).
  - Tipografía y Tamaños: Textos grandes, claros y botones táctiles de mínimo 48dp para uso rápido en pantallas táctiles o móviles.

---

## 6. Pipeline Obligatorio de Validación y Despliegue

### 6.1. Verificación Técnica
Antes de cerrar cualquier tarea:
1. `flutter pub get`
2. `flutter analyze` (debe reportar `No issues found!`).
3. `flutter test` si aplica.

### 6.2. Compilación Web Obligatoria en `docs/`
Todo cambio funcional o visual debe compilarse en la carpeta `docs/` para su despliegue inmediato en GitHub Pages:
```powershell
flutter build web --release --base-href="/kardexbar/" --output=docs
```

### 6.3. Inmutabilidad de Versión
No modificar el campo `version:` en `pubspec.yaml` sin autorización explícita. El código compilado se distribuye mediante GitHub Pages (`docs/`) y GitHub Releases.
