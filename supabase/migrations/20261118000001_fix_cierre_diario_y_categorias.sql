-- ==============================================================================
-- MIGRACIÓN: FIX CIERRE DIARIO (CAST CATEGORIA) Y TABLA CATEGORIAS (CRUD)
-- Archivo: supabase/migrations/20261118000001_fix_cierre_diario_y_categorias.sql
-- ==============================================================================

-- 1. FIX: Recrear generar_cierre_diario con CAST explícito a categoria_producto
CREATE OR REPLACE FUNCTION public.generar_cierre_diario(
    p_fecha DATE DEFAULT CURRENT_DATE,
    p_usuario_id UUID DEFAULT auth.uid()
)
RETURNS TABLE (
    cierre_id UUID,
    fecha DATE,
    producto_id UUID,
    codigo_producto TEXT,
    nombre_producto TEXT,
    categoria public.categoria_producto,
    unidad_medida TEXT,
    stock_inicial NUMERIC,
    surtido_dia NUMERIC,
    ventas_salidas_dia NUMERIC,
    stock_teorico NUMERIC,
    conteo_fisico NUMERIC,
    diferencia NUMERIC,
    cerrado BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
    r_prod RECORD;
    v_stock_inicial NUMERIC(12, 2);
    v_surtido_dia NUMERIC(12, 2);
    v_ventas_salidas_dia NUMERIC(12, 2);
    v_salidas_merma NUMERIC(12, 2);
    v_conteo_actual NUMERIC(12, 2);
    v_user UUID;
BEGIN
    IF p_fecha IS NULL THEN
        p_fecha := CURRENT_DATE;
    END IF;

    v_user := COALESCE(p_usuario_id, auth.uid());

    FOR r_prod IN
        SELECT p.id, p.codigo, p.nombre, p.categoria, p.unidad_medida, p.stock_actual
        FROM public.productos p
        WHERE p.es_inventariable = true
          AND p.activo = true
        ORDER BY p.categoria, p.nombre
    LOOP
        SELECT COALESCE(cd_ayer.conteo_fisico, cd_ayer.stock_teorico)
        INTO v_stock_inicial
        FROM public.cierres_diarios cd_ayer
        WHERE cd_ayer.fecha = (p_fecha - INTERVAL '1 day')::date
          AND cd_ayer.producto_id = r_prod.id;

        IF v_stock_inicial IS NULL THEN
            SELECT COALESCE(cd_ant.conteo_fisico, cd_ant.stock_teorico)
            INTO v_stock_inicial
            FROM public.cierres_diarios cd_ant
            WHERE cd_ant.fecha < p_fecha
              AND cd_ant.producto_id = r_prod.id
            ORDER BY cd_ant.fecha DESC
            LIMIT 1;
        END IF;

        IF v_stock_inicial IS NULL THEN
            v_stock_inicial := COALESCE(r_prod.stock_actual, 0.00);
        END IF;

        SELECT COALESCE(SUM(mi_in.cantidad), 0.00)
        INTO v_surtido_dia
        FROM public.movimientos_inventario mi_in
        WHERE mi_in.producto_id = r_prod.id
          AND mi_in.fecha_movimiento::date = p_fecha
          AND mi_in.tipo_movimiento IN ('ENTRADA_SURTIDO', 'AJUSTE_POSITIVO')
          AND (mi_in.referencia_origen NOT LIKE 'ANULACIÓN%' OR mi_in.referencia_origen IS NULL);

        SELECT COALESCE(SUM(dm.cantidad * re.factor_unidades_u), 0.00)
        INTO v_ventas_salidas_dia
        FROM public.detalle_movimientos dm
        JOIN public.movimientos m ON m.id = dm.movimiento_id
        JOIN public.recetas_equivalencias re ON re.presentacion_id = dm.presentacion_id
        WHERE re.producto_id = r_prod.id
          AND m.fecha_operacion::date = p_fecha
          AND m.estado = 'CONFIRMADO';

        SELECT COALESCE(SUM(mi_out.cantidad), 0.00)
        INTO v_salidas_merma
        FROM public.movimientos_inventario mi_out
        WHERE mi_out.producto_id = r_prod.id
          AND mi_out.fecha_movimiento::date = p_fecha
          AND mi_out.tipo_movimiento IN ('SALIDA_DESPERDICIO', 'AJUSTE_NEGATIVO');

        v_ventas_salidas_dia := v_ventas_salidas_dia + v_salidas_merma;

        SELECT cd_act.conteo_fisico
        INTO v_conteo_actual
        FROM public.cierres_diarios cd_act
        WHERE cd_act.fecha = p_fecha
          AND cd_act.producto_id = r_prod.id;

        INSERT INTO public.cierres_diarios (
            fecha,
            producto_id,
            stock_inicial,
            surtido_dia,
            ventas_salidas_dia,
            conteo_fisico,
            cerrado,
            usuario_id,
            observaciones
        ) VALUES (
            p_fecha,
            r_prod.id,
            v_stock_inicial,
            v_surtido_dia,
            v_ventas_salidas_dia,
            COALESCE(v_conteo_actual, 0.00),
            false,
            v_user,
            'Generado automáticamente por corte de barra'
        )
        ON CONFLICT (fecha, producto_id) DO UPDATE SET
            stock_inicial = EXCLUDED.stock_inicial,
            surtido_dia = EXCLUDED.surtido_dia,
            ventas_salidas_dia = EXCLUDED.ventas_salidas_dia,
            usuario_id = COALESCE(EXCLUDED.usuario_id, cierres_diarios.usuario_id),
            updated_at = timezone('utc'::text, now())
        WHERE cierres_diarios.cerrado = false;

    END LOOP;

    RETURN QUERY
    SELECT 
        cd.id AS cierre_id,
        cd.fecha,
        cd.producto_id,
        p.codigo AS codigo_producto,
        p.nombre AS nombre_producto,
        CASE
            WHEN p.categoria ILIKE '%coctel%' THEN 'COCTEL'::public.categoria_producto
            WHEN p.categoria ILIKE '%jugo%' OR p.categoria ILIKE '%no_alcoholica%' THEN 'BEBIDA_NO_ALCOHOLICA'::public.categoria_producto
            WHEN p.categoria ILIKE '%cerv%' THEN 'CERVEZA'::public.categoria_producto
            WHEN p.categoria ILIKE '%licor%' THEN 'LICOR'::public.categoria_producto
            WHEN p.categoria ILIKE '%serv%' THEN 'SERVICIO'::public.categoria_producto
            WHEN p.categoria ILIKE '%snack%' THEN 'SNACK'::public.categoria_producto
            ELSE 'OTRO'::public.categoria_producto
        END AS categoria,
        p.unidad_medida,
        cd.stock_inicial,
        cd.surtido_dia,
        cd.ventas_salidas_dia,
        cd.stock_teorico,
        cd.conteo_fisico,
        cd.diferencia,
        cd.cerrado
    FROM public.cierres_diarios cd
    JOIN public.productos p ON p.id = cd.producto_id
    WHERE cd.fecha = p_fecha
    ORDER BY p.categoria, p.nombre;
END;
$$;

-- 2. TABLA: categorias (CRUD dinámico desde el frontend)
CREATE TABLE IF NOT EXISTS public.categorias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL UNIQUE,
    descripcion TEXT,
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.categorias ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_select_categorias') THEN
        CREATE POLICY "anon_select_categorias" ON public.categorias FOR SELECT TO anon, authenticated USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_insert_categorias') THEN
        CREATE POLICY "anon_insert_categorias" ON public.categorias FOR INSERT TO anon, authenticated WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_update_categorias') THEN
        CREATE POLICY "anon_update_categorias" ON public.categorias FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_delete_categorias') THEN
        CREATE POLICY "anon_delete_categorias" ON public.categorias FOR DELETE TO anon, authenticated USING (true);
    END IF;
END $$;

INSERT INTO public.categorias (nombre, descripcion)
VALUES 
    ('Cervezas', 'Cervezas nacionales, importadas y artesanales'),
    ('Licores & Destilados', 'Rones, vodkas, whiskies, tequilas y ginebras'),
    ('Cócteles de Autor', 'Tragos preparados, cócteles clásicos y autor'),
    ('Sin Alcohol & Jugos', 'Jugos naturales, refrescos, aguas y mocktails'),
    ('Snacks', 'Frutos secos, aperitivos y botanas'),
    ('Otros', 'Otros insumos y conceptos de barra')
ON CONFLICT (nombre) DO NOTHING;
