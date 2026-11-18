-- ==============================================================================
-- MIGRACIÓN: MÓDULO KARDEXBAR - INSUMOS, RECETAS, COMANDAS Y MOVIMIENTOS KARDEX
-- Archivo: supabase/migrations/20261118000000_modulo_kardex_comandas_recetas.sql
-- ==============================================================================

-- 1. TABLA: insumos (Inventario físico en barra: botellas, jugos, frutas, jarabes)
CREATE TABLE IF NOT EXISTS public.insumos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL UNIQUE,
    unidad_medida TEXT NOT NULL CHECK (unidad_medida IN ('ml', 'unidad', 'gr')),
    stock_actual NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    stock_minimo NUMERIC(12, 2) NOT NULL DEFAULT 10.00 CHECK (stock_minimo >= 0),
    agotado BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 2. TABLA: productos (Catálogo comercial / Carta de venta)
-- Aseguramos que la tabla productos admita las categorías solicitadas y tenga columna precio
CREATE TABLE IF NOT EXISTS public.productos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo TEXT UNIQUE,
    nombre TEXT NOT NULL UNIQUE,
    descripcion TEXT,
    categoria TEXT NOT NULL DEFAULT 'Otros',
    precio NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (precio >= 0),
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.productos ADD COLUMN IF NOT EXISTS precio NUMERIC(12, 2) NOT NULL DEFAULT 0.00;

DO $$ BEGIN
    ALTER TABLE public.productos ALTER COLUMN categoria TYPE text;
EXCEPTION
    WHEN OTHERS THEN null;
END $$;

-- 3. TABLA: recetas (Relación Producto -> Insumo y cantidad de descuento)
CREATE TABLE IF NOT EXISTS public.recetas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    producto_id UUID NOT NULL REFERENCES public.productos(id) ON DELETE CASCADE,
    insumo_id UUID NOT NULL REFERENCES public.insumos(id) ON DELETE RESTRICT,
    cantidad_descuento NUMERIC(12, 2) NOT NULL CHECK (cantidad_descuento > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_recetas_producto_insumo UNIQUE (producto_id, insumo_id)
);

-- 4. TABLA: ventas_comandas (Encabezado de comanda recibida de caja)
CREATE TABLE IF NOT EXISTS public.ventas_comandas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    numero_ticket_caja TEXT NOT NULL,
    fecha TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    total NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (total >= 0),
    estado TEXT NOT NULL DEFAULT 'CONFIRMADO' CHECK (estado IN ('CONFIRMADO', 'ANULADO')),
    cliente_nombre TEXT,
    notas TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 5. TABLA: detalle_comandas (Renglones de comanda con clasificación de categoría)
CREATE TABLE IF NOT EXISTS public.detalle_comandas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    comanda_id UUID NOT NULL REFERENCES public.ventas_comandas(id) ON DELETE CASCADE,
    producto_id UUID NOT NULL REFERENCES public.productos(id) ON DELETE RESTRICT,
    categoria_clasificada TEXT NOT NULL CHECK (categoria_clasificada IN ('Cocteles', 'Jugos', 'Cervezas', 'Otros')),
    cantidad NUMERIC(10, 2) NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (precio_unitario >= 0),
    total NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (total >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 6. TABLA: movimientos_kardex (Trazabilidad física y auditoría de insumos)
CREATE TABLE IF NOT EXISTS public.movimientos_kardex (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    insumo_id UUID NOT NULL REFERENCES public.insumos(id) ON DELETE RESTRICT,
    tipo_movimiento TEXT NOT NULL CHECK (tipo_movimiento IN ('ENTRADA', 'MERMA', 'TRASPASO_SEDE_2', 'VENTA', 'AGOTADO')),
    cantidad NUMERIC(12, 2) NOT NULL CHECK (cantidad >= 0),
    motivo TEXT,
    destino TEXT,
    fecha TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    referencia_comanda_id UUID REFERENCES public.ventas_comandas(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 7. TRIGGER: Clasificación automática y cálculo de totales en detalle_comandas
CREATE OR REPLACE FUNCTION public.fn_clasificar_y_calcular_detalle_comanda()
RETURNS TRIGGER AS $$
DECLARE
    v_cat TEXT;
BEGIN
    IF NEW.categoria_clasificada IS NULL OR NEW.categoria_clasificada = '' THEN
        SELECT categoria INTO v_cat FROM public.productos WHERE id = NEW.producto_id;
        IF v_cat ILIKE '%coctel%' THEN
            NEW.categoria_clasificada := 'Cocteles';
        ELSIF v_cat ILIKE '%jugo%' OR v_cat ILIKE '%no_alcoholica%' THEN
            NEW.categoria_clasificada := 'Jugos';
        ELSIF v_cat ILIKE '%cerv%' THEN
            NEW.categoria_clasificada := 'Cervezas';
        ELSE
            NEW.categoria_clasificada := 'Otros';
        END IF;
    END IF;

    IF NEW.precio_unitario IS NULL OR NEW.precio_unitario = 0.00 THEN
        SELECT COALESCE(precio, 0.00) INTO NEW.precio_unitario FROM public.productos WHERE id = NEW.producto_id;
    END IF;

    NEW.total := ROUND(NEW.cantidad * NEW.precio_unitario, 2);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'trg_clasificar_y_calcular_detalle_comanda'
    ) THEN
        CREATE TRIGGER trg_clasificar_y_calcular_detalle_comanda
            BEFORE INSERT OR UPDATE ON public.detalle_comandas
            FOR EACH ROW
            EXECUTE FUNCTION public.fn_clasificar_y_calcular_detalle_comanda();
    END IF;
END $$;

-- 8. TRIGGER: Descuento automático de stock en insumos según recetas al registrar comanda
CREATE OR REPLACE FUNCTION public.fn_descontar_insumos_por_comanda()
RETURNS TRIGGER AS $$
DECLARE
    rec RECORD;
    v_descuento NUMERIC(12, 2);
    v_ticket TEXT;
    v_producto_nombre TEXT;
BEGIN
    SELECT numero_ticket_caja INTO v_ticket FROM public.ventas_comandas WHERE id = NEW.comanda_id;
    SELECT nombre INTO v_producto_nombre FROM public.productos WHERE id = NEW.producto_id;

    FOR rec IN
        SELECT insumo_id, cantidad_descuento
        FROM public.recetas
        WHERE producto_id = NEW.producto_id
    LOOP
        v_descuento := ROUND(NEW.cantidad * rec.cantidad_descuento, 2);

        UPDATE public.insumos
        SET stock_actual = GREATEST(stock_actual - v_descuento, 0.00),
            agotado = CASE WHEN (stock_actual - v_descuento) <= 0.00 THEN true ELSE agotado END,
            updated_at = timezone('utc'::text, now())
        WHERE id = rec.insumo_id;

        INSERT INTO public.movimientos_kardex (
            insumo_id,
            tipo_movimiento,
            cantidad,
            motivo,
            destino,
            fecha,
            referencia_comanda_id
        ) VALUES (
            rec.insumo_id,
            'VENTA',
            v_descuento,
            'Despacho Comanda ' || COALESCE(v_ticket, 'S/N') || ' (' || NEW.cantidad || 'x ' || COALESCE(v_producto_nombre, 'Item') || ')',
            'Barra Principal',
            timezone('utc'::text, now()),
            NEW.comanda_id
        );
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'trg_descontar_insumos_por_comanda'
    ) THEN
        CREATE TRIGGER trg_descontar_insumos_por_comanda
            AFTER INSERT ON public.detalle_comandas
            FOR EACH ROW
            EXECUTE FUNCTION public.fn_descontar_insumos_por_comanda();
    END IF;
END $$;

-- 9. RPC: Registrar comanda completa de forma atómica
CREATE OR REPLACE FUNCTION public.registrar_comanda_completa(
    p_numero_ticket_caja TEXT,
    p_items JSONB,
    p_cliente_nombre TEXT DEFAULT NULL,
    p_notas TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_comanda_id UUID;
    v_total_comanda NUMERIC(12, 2) := 0.00;
    elem JSONB;
    v_prod_id UUID;
    v_cant NUMERIC(10, 2);
    v_precio NUMERIC(12, 2);
    v_cat TEXT;
    v_subtotal NUMERIC(12, 2);
    v_res JSONB;
BEGIN
    INSERT INTO public.ventas_comandas (
        numero_ticket_caja,
        fecha,
        total,
        estado,
        cliente_nombre,
        notas
    ) VALUES (
        p_numero_ticket_caja,
        timezone('utc'::text, now()),
        0.00,
        'CONFIRMADO',
        p_cliente_nombre,
        p_notas
    ) RETURNING id INTO v_comanda_id;

    FOR elem IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_prod_id := (elem->>'producto_id')::UUID;
        v_cant := (elem->>'cantidad')::NUMERIC;
        v_precio := COALESCE((elem->>'precio_unitario')::NUMERIC, 0.00);
        v_cat := elem->>'categoria';

        IF v_precio = 0.00 THEN
            SELECT COALESCE(precio, 0.00), COALESCE(v_cat, categoria)
            INTO v_precio, v_cat
            FROM public.productos WHERE id = v_prod_id;
        END IF;

        IF v_cat IS NULL OR v_cat NOT IN ('Cocteles', 'Jugos', 'Cervezas', 'Otros') THEN
            IF v_cat ILIKE '%coctel%' THEN v_cat := 'Cocteles';
            ELSIF v_cat ILIKE '%jugo%' OR v_cat ILIKE '%no_alcoholica%' THEN v_cat := 'Jugos';
            ELSIF v_cat ILIKE '%cerv%' THEN v_cat := 'Cervezas';
            ELSE v_cat := 'Otros';
            END IF;
        END IF;

        v_subtotal := ROUND(v_cant * v_precio, 2);
        v_total_comanda := v_total_comanda + v_subtotal;

        INSERT INTO public.detalle_comandas (
            comanda_id,
            producto_id,
            categoria_clasificada,
            cantidad,
            precio_unitario,
            total
        ) VALUES (
            v_comanda_id,
            v_prod_id,
            v_cat,
            v_cant,
            v_precio,
            v_subtotal
        );
    END LOOP;

    UPDATE public.ventas_comandas
    SET total = v_total_comanda
    WHERE id = v_comanda_id;

    SELECT jsonb_build_object(
        'comanda_id', v_comanda_id,
        'numero_ticket_caja', p_numero_ticket_caja,
        'total', v_total_comanda,
        'fecha', timezone('utc'::text, now())
    ) INTO v_res;

    RETURN v_res;
END;
$$;

-- 10. POLÍTICAS RLS (Seguridad en Supabase para lectura y escritura)
ALTER TABLE public.insumos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recetas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ventas_comandas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.detalle_comandas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.movimientos_kardex ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_select_insumos') THEN
        CREATE POLICY "anon_select_insumos" ON public.insumos FOR SELECT TO anon, authenticated USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_insert_insumos') THEN
        CREATE POLICY "anon_insert_insumos" ON public.insumos FOR INSERT TO anon, authenticated WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_update_insumos') THEN
        CREATE POLICY "anon_update_insumos" ON public.insumos FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_select_recetas') THEN
        CREATE POLICY "anon_select_recetas" ON public.recetas FOR SELECT TO anon, authenticated USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_insert_recetas') THEN
        CREATE POLICY "anon_insert_recetas" ON public.recetas FOR INSERT TO anon, authenticated WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_update_recetas') THEN
        CREATE POLICY "anon_update_recetas" ON public.recetas FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_select_comandas') THEN
        CREATE POLICY "anon_select_comandas" ON public.ventas_comandas FOR SELECT TO anon, authenticated USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_insert_comandas') THEN
        CREATE POLICY "anon_insert_comandas" ON public.ventas_comandas FOR INSERT TO anon, authenticated WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_update_comandas') THEN
        CREATE POLICY "anon_update_comandas" ON public.ventas_comandas FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_select_det_comandas') THEN
        CREATE POLICY "anon_select_det_comandas" ON public.detalle_comandas FOR SELECT TO anon, authenticated USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_insert_det_comandas') THEN
        CREATE POLICY "anon_insert_det_comandas" ON public.detalle_comandas FOR INSERT TO anon, authenticated WITH CHECK (true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_select_mov_kardex') THEN
        CREATE POLICY "anon_select_mov_kardex" ON public.movimientos_kardex FOR SELECT TO anon, authenticated USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_insert_mov_kardex') THEN
        CREATE POLICY "anon_insert_mov_kardex" ON public.movimientos_kardex FOR INSERT TO anon, authenticated WITH CHECK (true);
    END IF;
END $$;
