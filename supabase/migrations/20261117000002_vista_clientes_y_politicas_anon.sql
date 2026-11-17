-- ==============================================================================
-- MIGRACIÓN: VISTA DE CLIENTES RESUMEN Y POLÍTICAS RLS PARA ACCESO ANÓNIMO POS
-- Archivo: supabase/migrations/20261117000002_vista_clientes_y_politicas_anon.sql
-- ==============================================================================

-- 1. Vista para consultar clientes con compras previas registradas
CREATE OR REPLACE VIEW public.vista_clientes_resumen AS
SELECT 
    cliente_nombre,
    count(*)::integer AS total_compras,
    max(fecha_operacion) AS ultima_compra,
    sum(total)::numeric(12,2) AS total_gastado,
    (array_agg(numero_ticket ORDER BY fecha_operacion DESC))[1] AS ultimo_ticket
FROM public.movimientos
WHERE cliente_nombre IS NOT NULL AND trim(cliente_nombre) != ''
GROUP BY cliente_nombre;

-- 2. Políticas RLS para permitir operaciones del POS bajo rol anon
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'movimientos_select_anon') THEN
        CREATE POLICY "movimientos_select_anon" ON public.movimientos FOR SELECT TO anon USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'movimientos_insert_anon') THEN
        CREATE POLICY "movimientos_insert_anon" ON public.movimientos FOR INSERT TO anon WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'detalle_movimientos_select_anon') THEN
        CREATE POLICY "detalle_movimientos_select_anon" ON public.detalle_movimientos FOR SELECT TO anon USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'detalle_movimientos_insert_anon') THEN
        CREATE POLICY "detalle_movimientos_insert_anon" ON public.detalle_movimientos FOR INSERT TO anon WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'movimientos_inventario_select_anon') THEN
        CREATE POLICY "movimientos_inventario_select_anon" ON public.movimientos_inventario FOR SELECT TO anon USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'movimientos_inventario_insert_anon') THEN
        CREATE POLICY "movimientos_inventario_insert_anon" ON public.movimientos_inventario FOR INSERT TO anon WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'productos_select_anon') THEN
        CREATE POLICY "productos_select_anon" ON public.productos FOR SELECT TO anon USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'presentaciones_select_anon') THEN
        CREATE POLICY "presentaciones_select_anon" ON public.presentaciones_venta FOR SELECT TO anon USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'recetas_select_anon') THEN
        CREATE POLICY "recetas_select_anon" ON public.recetas_equivalencias FOR SELECT TO anon USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'historial_precios_select_anon') THEN
        CREATE POLICY "historial_precios_select_anon" ON public.historial_precios FOR SELECT TO anon USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'cierres_select_anon') THEN
        CREATE POLICY "cierres_select_anon" ON public.cierres_diarios FOR SELECT TO anon USING (true);
    END IF;
END $$;
