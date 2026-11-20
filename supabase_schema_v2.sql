-- ==============================================================================
-- KARDEXBAR - SUPABASE ESQUEMA V2
-- Modelo de datos unificado: 8 Tablas + Triggers de Stock + RPC Arqueo Diario
-- ==============================================================================

-- 1. TABLA: categorias
CREATE TABLE IF NOT EXISTS public.categorias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT UNIQUE NOT NULL,
    orden INT DEFAULT 0,
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.categorias ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'categorias' AND policyname = 'allow_all_categorias') THEN
        CREATE POLICY "allow_all_categorias" ON public.categorias FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
    END IF;
END $$;

INSERT INTO public.categorias (nombre, orden, activo)
VALUES 
    ('Cervezas', 1, true),
    ('Licores & Destilados', 2, true),
    ('Cócteles de Autor', 3, true),
    ('Sin Alcohol & Jugos', 4, true),
    ('Servicios & Descorche', 5, true),
    ('Snacks', 6, true),
    ('Otros', 7, true)
ON CONFLICT (nombre) DO NOTHING;

-- 2. TABLA: canales_origen
CREATE TABLE IF NOT EXISTS public.canales_origen (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo TEXT UNIQUE NOT NULL,
    nombre TEXT NOT NULL,
    es_cuenta_interna BOOLEAN NOT NULL DEFAULT false,
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.canales_origen ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'canales_origen' AND policyname = 'allow_all_canales_origen') THEN
        CREATE POLICY "allow_all_canales_origen" ON public.canales_origen FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
    END IF;
END $$;

INSERT INTO public.canales_origen (codigo, nombre, es_cuenta_interna, activo)
VALUES
    ('REGULAR', 'Venta Regular', false, true),
    ('CUMPLEANOS', 'Cumpleañeros', false, true),
    ('RESERVACIONES', 'Reservaciones', false, true),
    ('COMBOS', 'Combos', false, true),
    ('DESCORCHE', 'Servicio de Descorche', false, true),
    ('T_PELUCHE', 'Cuenta Interna Peluche', true, true),
    ('T_TRABAJADORES', 'Consumo Trabajadores', true, true)
ON CONFLICT (codigo) DO UPDATE SET
    nombre = EXCLUDED.nombre,
    es_cuenta_interna = EXCLUDED.es_cuenta_interna,
    activo = EXCLUDED.activo;

-- 3. TABLA: insumos
CREATE TABLE IF NOT EXISTS public.insumos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo TEXT UNIQUE,
    nombre TEXT UNIQUE NOT NULL,
    categoria_id UUID REFERENCES public.categorias(id) ON DELETE SET NULL,
    unidad_medida TEXT NOT NULL DEFAULT 'UND' CHECK (unidad_medida IN ('UND', 'ML', 'VASO', 'SRV', 'unidad', 'ml', 'gr')),
    stock_actual NUMERIC NOT NULL DEFAULT 0,
    stock_minimo NUMERIC NOT NULL DEFAULT 10,
    agotado BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'insumos' AND column_name = 'codigo') THEN
        ALTER TABLE public.insumos ADD COLUMN codigo TEXT UNIQUE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'insumos' AND column_name = 'categoria_id') THEN
        ALTER TABLE public.insumos ADD COLUMN categoria_id UUID REFERENCES public.categorias(id) ON DELETE SET NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'insumos' AND column_name = 'agotado') THEN
        ALTER TABLE public.insumos ADD COLUMN agotado BOOLEAN NOT NULL DEFAULT false;
    END IF;
END $$;

ALTER TABLE public.insumos ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'insumos' AND policyname = 'allow_all_insumos') THEN
        CREATE POLICY "allow_all_insumos" ON public.insumos FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
    END IF;
END $$;

-- 4. TABLA: productos
CREATE TABLE IF NOT EXISTS public.productos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo TEXT UNIQUE,
    nombre TEXT UNIQUE NOT NULL,
    categoria_id UUID REFERENCES public.categorias(id) ON DELETE SET NULL,
    insumo_id UUID REFERENCES public.insumos(id) ON DELETE SET NULL,
    precio NUMERIC NOT NULL DEFAULT 0,
    factor_unidades NUMERIC NOT NULL DEFAULT 1,
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'productos' AND column_name = 'categoria_id') THEN
        ALTER TABLE public.productos ADD COLUMN categoria_id UUID REFERENCES public.categorias(id) ON DELETE SET NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'productos' AND column_name = 'insumo_id') THEN
        ALTER TABLE public.productos ADD COLUMN insumo_id UUID REFERENCES public.insumos(id) ON DELETE SET NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'productos' AND column_name = 'factor_unidades') THEN
        ALTER TABLE public.productos ADD COLUMN factor_unidades NUMERIC NOT NULL DEFAULT 1;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'productos' AND column_name = 'precio') THEN
        ALTER TABLE public.productos ADD COLUMN precio NUMERIC NOT NULL DEFAULT 0;
    END IF;
END $$;

ALTER TABLE public.productos ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'productos' AND policyname = 'allow_all_productos') THEN
        CREATE POLICY "allow_all_productos" ON public.productos FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
    END IF;
END $$;

-- 5. TABLA: comandas
CREATE TABLE IF NOT EXISTS public.comandas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    numero_ticket TEXT NOT NULL,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    dia_semana TEXT,
    cliente TEXT,
    canal_id UUID REFERENCES public.canales_origen(id) ON DELETE SET NULL,
    origen_excel_raw TEXT,
    mesero TEXT,
    metodo_pago TEXT NOT NULL DEFAULT 'EFECTIVO_USD',
    subtotal NUMERIC NOT NULL DEFAULT 0,
    descuento NUMERIC NOT NULL DEFAULT 0,
    total NUMERIC NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.comandas ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'comandas' AND policyname = 'allow_all_comandas') THEN
        CREATE POLICY "allow_all_comandas" ON public.comandas FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
    END IF;
END $$;

-- 6. TABLA: detalle_comandas
CREATE TABLE IF NOT EXISTS public.detalle_comandas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    comanda_id UUID NOT NULL REFERENCES public.comandas(id) ON DELETE CASCADE,
    producto_id UUID NOT NULL REFERENCES public.productos(id) ON DELETE RESTRICT,
    cantidad NUMERIC NOT NULL DEFAULT 1,
    unidades_descontadas NUMERIC NOT NULL DEFAULT 1,
    precio_unitario NUMERIC NOT NULL DEFAULT 0,
    total_linea NUMERIC NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'detalle_comandas' AND column_name = 'unidades_descontadas') THEN
        ALTER TABLE public.detalle_comandas ADD COLUMN unidades_descontadas NUMERIC NOT NULL DEFAULT 1;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'detalle_comandas' AND column_name = 'total_linea') THEN
        ALTER TABLE public.detalle_comandas ADD COLUMN total_linea NUMERIC NOT NULL DEFAULT 0;
    END IF;
END $$;

ALTER TABLE public.detalle_comandas ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'detalle_comandas' AND policyname = 'allow_all_detalle_comandas') THEN
        CREATE POLICY "allow_all_detalle_comandas" ON public.detalle_comandas FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
    END IF;
END $$;

-- 7. TABLA: auditoria_diferencias
DROP TABLE IF EXISTS public.auditoria_diferencias CASCADE;

CREATE TABLE public.auditoria_diferencias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    cliente TEXT,
    mesero TEXT,
    producto_id UUID REFERENCES public.productos(id) ON DELETE SET NULL,
    precio_unitario NUMERIC NOT NULL DEFAULT 0,
    cant_caja NUMERIC NOT NULL DEFAULT 0,
    cant_barra NUMERIC NOT NULL DEFAULT 0,
    diferencia_unidades NUMERIC GENERATED ALWAYS AS (cant_barra - cant_caja) STORED,
    total_diferencia NUMERIC NOT NULL DEFAULT 0,
    observacion TEXT,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.auditoria_diferencias ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'auditoria_diferencias' AND policyname = 'allow_all_auditoria_diferencias') THEN
        CREATE POLICY "allow_all_auditoria_diferencias" ON public.auditoria_diferencias FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
    END IF;
END $$;

-- 8. TABLA: movimientos_kardex
CREATE TABLE IF NOT EXISTS public.movimientos_kardex (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    insumo_id UUID NOT NULL REFERENCES public.insumos(id) ON DELETE CASCADE,
    tipo_movimiento TEXT NOT NULL CHECK (tipo_movimiento IN ('ENTRADA', 'VENTA', 'MERMA', 'TRASPASO_SEDE_2', 'AJUSTE_ARQUEO', 'AGOTADO')),
    cantidad NUMERIC NOT NULL,
    destino TEXT DEFAULT 'Barra Principal',
    motivo TEXT,
    referencia_id UUID,
    fecha TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'movimientos_kardex' AND column_name = 'referencia_id') THEN
        ALTER TABLE public.movimientos_kardex ADD COLUMN referencia_id UUID;
    END IF;
END $$;

ALTER TABLE public.movimientos_kardex ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'movimientos_kardex' AND policyname = 'allow_all_movimientos_kardex') THEN
        CREATE POLICY "allow_all_movimientos_kardex" ON public.movimientos_kardex FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
    END IF;
END $$;

-- ==============================================================================
-- TRIGGER EN DETALLE_COMANDAS: DESCUENTO AUTOMÁTICO DE STOCK Y MOVIMIENTO KARDEX
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.fn_trg_procesar_detalle_comanda()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_factor NUMERIC;
    v_insumo_id UUID;
    v_precio_prod NUMERIC;
    v_ticket TEXT;
BEGIN
    -- 1. Obtener datos del producto asociado
    SELECT factor_unidades, insumo_id, precio
    INTO v_factor, v_insumo_id, v_precio_prod
    FROM public.productos
    WHERE id = NEW.producto_id;

    v_factor := COALESCE(v_factor, 1);

    -- 2. Asegurar cálculo de unidades_descontadas y total_linea
    IF NEW.unidades_descontadas IS NULL OR NEW.unidades_descontadas <= 0 THEN
        NEW.unidades_descontadas := NEW.cantidad * v_factor;
    END IF;

    IF NEW.precio_unitario IS NULL OR NEW.precio_unitario = 0 THEN
        NEW.precio_unitario := COALESCE(v_precio_prod, 0);
    END IF;

    IF NEW.total_linea IS NULL OR NEW.total_linea = 0 THEN
        NEW.total_linea := NEW.cantidad * NEW.precio_unitario;
    END IF;

    -- Si se solicita saltar la actualización de inventario (ej. en carga masiva si se desea):
    IF current_setting('kardexbar.skip_triggers', true) = 'true' THEN
        RETURN NEW;
    END IF;

    -- 3. Descontar del stock físico en insumos si el producto tiene insumo vinculado
    IF v_insumo_id IS NOT NULL THEN
        UPDATE public.insumos
        SET 
            stock_actual = stock_actual - NEW.unidades_descontadas,
            agotado = ((stock_actual - NEW.unidades_descontadas) <= 0),
            updated_at = timezone('utc'::text, now())
        WHERE id = v_insumo_id;

        -- 4. Registrar la traza en movimientos_kardex
        SELECT numero_ticket INTO v_ticket FROM public.comandas WHERE id = NEW.comanda_id;

        INSERT INTO public.movimientos_kardex (
            insumo_id,
            tipo_movimiento,
            cantidad,
            destino,
            motivo,
            referencia_id,
            fecha
        ) VALUES (
            v_insumo_id,
            'VENTA',
            NEW.unidades_descontadas,
            'Barra Principal',
            COALESCE('Venta ticket ' || v_ticket, 'Venta comanda'),
            NEW.comanda_id,
            timezone('utc'::text, now())
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_procesar_detalle_comanda ON public.detalle_comandas;

CREATE TRIGGER trg_procesar_detalle_comanda
BEFORE INSERT ON public.detalle_comandas
FOR EACH ROW
EXECUTE FUNCTION public.fn_trg_procesar_detalle_comanda();

-- ==============================================================================
-- RPC CORREGIDA: generar_cierre_diario (SIN ERROR 42804, CATEGORIA TEXT)
-- ==============================================================================

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
    categoria TEXT,
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
    v_conteo_actual NUMERIC(12, 2);
    v_user UUID;
BEGIN
    IF p_fecha IS NULL THEN
        p_fecha := CURRENT_DATE;
    END IF;

    v_user := COALESCE(p_usuario_id, auth.uid());

    -- Iterar por productos inventariables o insumos activos
    FOR r_prod IN
        SELECT 
            p.id, 
            COALESCE(p.codigo, 'S/C') as codigo, 
            p.nombre, 
            COALESCE(c.nombre, 'General') as categoria_nombre, 
            COALESCE(i.unidad_medida, 'UND') as unidad_medida, 
            COALESCE(i.stock_actual, 0) as stock_actual
        FROM public.productos p
        LEFT JOIN public.categorias c ON c.id = p.categoria_id
        LEFT JOIN public.insumos i ON i.id = p.insumo_id
        WHERE p.activo = true
        ORDER BY c.nombre, p.nombre
    LOOP
        -- 1. Determinar stock inicial desde cierre previo
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

        -- 2. Entradas/surtido del día desde movimientos_kardex
        SELECT COALESCE(SUM(mk.cantidad), 0.00)
        INTO v_surtido_dia
        FROM public.movimientos_kardex mk
        JOIN public.productos pr ON pr.insumo_id = mk.insumo_id
        WHERE pr.id = r_prod.id
          AND mk.fecha::date = p_fecha
          AND mk.tipo_movimiento = 'ENTRADA';

        -- 3. Salidas teóricas por ventas del día
        SELECT COALESCE(SUM(dc.unidades_descontadas), 0.00)
        INTO v_ventas_salidas_dia
        FROM public.detalle_comandas dc
        JOIN public.comandas com ON com.id = dc.comanda_id
        WHERE dc.producto_id = r_prod.id
          AND com.fecha = p_fecha;

        -- 4. Obtener conteo existente si ya se ingresó
        SELECT cd_act.conteo_fisico
        INTO v_conteo_actual
        FROM public.cierres_diarios cd_act
        WHERE cd_act.fecha = p_fecha
          AND cd_act.producto_id = r_prod.id;

        -- 5. Upsert en cierres_diarios
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
            COALESCE(v_conteo_actual, v_stock_inicial + v_surtido_dia - v_ventas_salidas_dia),
            false,
            v_user,
            'Generado automáticamente por arqueo de barra'
        )
        ON CONFLICT (fecha, producto_id) DO UPDATE SET
            stock_inicial = EXCLUDED.stock_inicial,
            surtido_dia = EXCLUDED.surtido_dia,
            ventas_salidas_dia = EXCLUDED.ventas_salidas_dia,
            updated_at = timezone('utc'::text, now())
        WHERE cierres_diarios.cerrado = false;

    END LOOP;

    -- 6. Retornar el set de datos para Flutter (con categoria como TEXT)
    RETURN QUERY
    SELECT 
        cd.id AS cierre_id,
        cd.fecha,
        cd.producto_id,
        COALESCE(p.codigo, 'S/C') AS codigo_producto,
        p.nombre AS nombre_producto,
        COALESCE(c.nombre, 'General')::TEXT AS categoria,
        COALESCE(i.unidad_medida, 'UND') AS unidad_medida,
        cd.stock_inicial,
        cd.surtido_dia,
        cd.ventas_salidas_dia,
        cd.stock_teorico,
        cd.conteo_fisico,
        cd.diferencia,
        cd.cerrado
    FROM public.cierres_diarios cd
    JOIN public.productos p ON p.id = cd.producto_id
    LEFT JOIN public.categorias c ON c.id = p.categoria_id
    LEFT JOIN public.insumos i ON i.id = p.insumo_id
    WHERE cd.fecha = p_fecha
    ORDER BY c.nombre, p.nombre;
END;
$$;
