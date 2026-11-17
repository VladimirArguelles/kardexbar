# KardexBar - Control de Ventas, Barra e Inventario

Sistema de registro de control de ventas, comandas, arqueo de barra e inventario físico para bares y discotecas, construido con Flutter y Supabase (PostgreSQL 17).

## Configuración de Supabase

- **Project ID:** `raqmozfiuyoctylzxnms`
- **URL:** `https://raqmozfiuyoctylzxnms.supabase.co`
- **Región:** `us-west-2`

### Variables de Entorno (`.env`)

```env
SUPABASE_URL=https://raqmozfiuyoctylzxnms.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJhcW1vemZpdXlvY3R5bHp4bm1zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ4ODA1MjcsImV4cCI6MjExMDQ1NjUyN30.8QwLZODpwJQfoIBg1J8HyFwR4mkvX8X12XL-UhQzozU
SUPABASE_PUBLISHABLE_KEY=sb_publishable_bRz8HXWqTSSPKREccvnu1Q_wPkveXyo
```

## Estructura de Migraciones

- `supabase/migrations/20261117000000_init_control_ventas_inventario.sql`: Esquema base de datos, tipos ENUM, triggers de stock y RLS.
- `supabase/migrations/20261117000001_rpc_cierre_diario.sql`: Procedimientos almacenados para el cálculo automático del cierre y corte de turno.
- `supabase/seed.sql`: Catálogo base de productos, presentaciones, factores de desconsolidación y tarifas.
