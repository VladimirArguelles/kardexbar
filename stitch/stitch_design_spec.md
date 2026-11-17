# KardexBar - Especificación de Diseño para el Agente Google Stitch

Este documento contiene la arquitectura visual, tokens de diseño y los **prompts maestros exactos** para ser introducidos en el agente de diseño **Google Stitch** (`stitch.withgoogle.com`) para sincronizar, iterar y generar componentes visuales de alta fidelidad para la aplicación Flutter en Visual Studio Code.

---

## 1. Sistema de Diseño (Design Tokens & Color Palette)

El diseño está optimizado para ambientes nocturnos de alta exigencia (bares, lounges y discotecas) donde la visibilidad bajo poca luz, la velocidad táctil del bartender y el alto contraste son críticos.

| Token Visual | Código HEX | Rol en la Interfaz | Equivalente Flutter M3 |
| :--- | :--- | :--- | :--- |
| **Obsidian Dark** | `#0F1117` | Fondo principal (Scaffold Background) | `AppTheme.background` |
| **Charcoal Surface** | `#161922` | Tarjetas, barras y modales (Cards/Bars) | `AppTheme.surface` |
| **Slate Highlight** | `#1F2432` | Inputs, chips inactivos y bordes | `AppTheme.surfaceVariant` |
| **Neon Amber** | `#FFB703` | Botones de cobro, precios y totales | `AppTheme.primaryAmber` |
| **Acid Orange** | `#FB8500` | Etiquetas de recetas y desconsolidación | `AppTheme.primaryOrange` |
| **Cyan Neon** | `#00E5FF` | Stock teórico y canales de venta | `AppTheme.secondaryCyan` |
| **Mint Healthy** | `#06D6A0` | Stock óptimo y cuadre exacto | `AppTheme.successMint` |
| **Coral Alert** | `#EF476F` | Faltantes en arqueo y bajo stock crítico | `AppTheme.errorCoral` |
| **Royal Violet** | `#8338EC` | Sobrantes de inventario y reservas VIP | `AppTheme.infoViolet` |

---

## 2. Prompts Maestros para el Agente Stitch (`stitch.withgoogle.com`)

### 🍹 Pantalla 1: POS & Comandas Rápidas de Barra
**Prompt para el Agente Stitch:**
```text
Create a high-contrast dark mode Point-of-Sale (POS) touch interface for a high-volume nightclub bar named 'KardexBar'.
The screen must feature:
1. Top Bar: Search bar for beverages, category filter chips (All, Cervezas, Licores, Cócteles, Sin Alcohol, Servicios).
2. Product Grid (2 to 3 columns): Cards featuring beverage title, product code, price highlighted in neon amber (#FFB703), category pill, and recipe deconsolidation preview (e.g., '10x Cerveza Zulia 222ml' for bucket orders). Quantity increment/decrement buttons with haptic feedback.
3. Right-side Comanda / Checkout Drawer:
   - Order items list showing quantity, unit price, and subtotal.
   - Channel selector pills: [Barra Principal], [Mesas], [VIP].
   - Payment method dropdown: [USD Cash], [Bolívares], [Pago Móvil], [Punto Tarjeta], [Zelle].
   - Subtotal, Discount row, and large Total sum display.
   - High-visibility primary action button: 'DESPACHAR Y REGISTRAR' in neon amber with obsidian text.
4. Style: Deep dark obsidian theme (#0F1117), glowing borders, modern rounded corners (16px), clean typography (Syne & Inter).
```

---

### 📦 Pantalla 2: Control de Inventario Físico & Kardex
**Prompt para el Agente Stitch:**
```text
Design a physical stock and inventory management screen for a bar/disco backroom in 'KardexBar'.
Requirements:
1. Search and category pills at the top for quick inventory lookup.
2. List of inventory cards displaying:
   - Insumo name (e.g. Cerveza Zulia, Whisky 12 Años, Ron Añejo).
   - Category badge and unit of measurement (UND, LATA, COPA).
   - Stock level progress indicator bar (color-coded: mint green #06D6A0 when above minimum, vibrant coral red #EF476F when critical/requires restock).
   - Current stock vs. minimum threshold numbers.
   - Quick Action context menu with options: 'Ingresar Surtido de Bodega' and 'Registrar Merma / Rotura de Botella'.
3. Modal Dialog for Restock / Waste:
   - Numerical keypad entry for quantity.
   - Justification/Notes text field.
   - Confirm action button.
```

---

### ⚖️ Pantalla 3: Cierre de Turno y Arqueo Diario (Blind Count & Audit)
**Prompt para el Agente Stitch:**
```text
Design an automated daily bar closing and physical reconciliation audit screen for 'KardexBar'.
Requirements:
1. Top Summary Cards (4 KPIs): Total Audited Products, Exact Matches (#06D6A0), Missing Discrepancies / Faltantes (#EF476F), Excess Stock / Sobrantes (#8338EC).
2. Interactive Reconciliation Table with columns:
   - Insumo / Producto name and code.
   - Stock Inicial (from yesterday's close).
   - Surtido (+) (deliveries during the shift).
   - Ventas/Salidas (-) (automated deductions from confirmed sales orders).
   - Stock Teórico (calculated stock in cyan #00E5FF).
   - Conteo Físico (editable input field for the bartender's physical bottle count).
   - Diferencia (computed difference badge: 'EXACTO', '-2.00 UND Faltante', or '+1.00 UND Sobrante').
3. Shift sign-off footer:
   - Bartender observations text field.
   - Floating action button: 'FINALIZAR Y CERRAR TURNO' in golden amber.
```

---

### 📊 Pantalla 4: Dashboard y Métricas de Rendimiento
**Prompt para el Agente Stitch:**
```text
Design a luxury bar executive dashboard screen in dark mode.
Requirements:
1. Top Status Banner: 'Supabase PostgreSQL 17 Online' with pulsing green indicator.
2. 4 Metric Cards with micro-charts:
   - Recent Sales Total ($) with growth indicator.
   - Tickets / Comandas Dispatch count.
   - Active Bar Stock count.
   - Critical Low Stock Alert count.
3. Recent Transactions Table:
   - Ticket Number (e.g. TICK-20261117-A1B2).
   - Timestamp and Payment method pill (Efectivo, Zelle, Pago Móvil).
   - Sale channel tag (Barra, VIP, Reservación).
   - Total amount in bold amber.
```

---

## 3. Correspondencia entre Stitch y los Componentes Flutter Implementados

| Componente en Stitch | Archivo Flutter en `lib/` | Descripción Funcional |
| :--- | :--- | :--- |
| **Main Navigation** | `lib/ui/screens/main_layout_screen.dart` | NavigationRail responsivo en Desktop/Web y NavigationBar en Móvil. |
| **POS Grid & Card** | `lib/ui/widgets/product_card.dart` | Renderiza el ítem, precio, desconsolidación de baldes/cajas y conteo. |
| **Comanda Drawer** | `lib/ui/screens/pos_screen.dart` | Gestión de carrito, canal, pagos y disparo de triggers automáticos. |
| **Kardex Cards** | `lib/ui/screens/inventario_screen.dart` | Progreso de stock, surtido de bodega y registro de mermas. |
| **Tabla de Arqueo** | `lib/ui/screens/cierre_screen.dart` | Conexión directa a RPC `generar_cierre_diario` y `registrar_conteo_fisico_y_cerrar`. |
| **Difference Badges** | `lib/ui/widgets/difference_badge.dart` | Indicadores de faltante (-), sobrante (+) y exacto (=). |
| **KPI Metrics** | `lib/ui/widgets/metric_card.dart` | Tarjetas modulares de datos clave. |

---

## 4. Ejecución y Depuración en Visual Studio / VS Code

1. Abrir la carpeta del proyecto en **Visual Studio Code**.
2. Presionar `F5` o seleccionar el perfil de depuración en `.vscode/launch.json`:
   - `KardexBar (Debug - Windows)`: Para ejecutar como app nativa de escritorio en Windows.
   - `KardexBar (Debug - Chrome Web)`: Para ejecutar en navegador Chrome con hot reload.
3. Todas las operaciones de venta y arqueo sincronizan en tiempo real con la base de datos de **Supabase** (`raqmozfiuyoctylzxnms`).
