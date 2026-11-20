-- ==============================================================================
-- MIGRACIÓN INTEGRAL: CONTROL DE BARRA Y KARDEX (KARDEXBAR)
-- Archivo: supabase/migrations/20261120_refactor_kardex_barra.sql
-- ==============================================================================

-- 0. EXTENSIONES
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==============================================================================
-- 1. TABLAS PRINCIPALES
-- ==============================================================================

-- 1.1. TABLA: sedes
CREATE TABLE IF NOT EXISTS public.sedes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL UNIQUE,
    es_principal BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 1.2. TABLA: productos_barra
CREATE TABLE IF NOT EXISTS public.productos_barra (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL UNIQUE,
    categoria TEXT NOT NULL CHECK (categoria IN ('Cervezas', 'Licores', 'Cocteles', 'Jugos', 'No Alcoholicas')),
    precio_venta NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (precio_venta >= 0),
    es_receta BOOLEAN NOT NULL DEFAULT false,
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 1.3. TABLA: insumos_inventario
CREATE TABLE IF NOT EXISTS public.insumos_inventario (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sede_id UUID NOT NULL REFERENCES public.sedes(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    unidad_medida TEXT NOT NULL CHECK (unidad_medida IN ('unidad', 'caja', 'ml', 'gr', 'bolsa_hielo')),
    stock_actual NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    stock_minimo NUMERIC(12, 2) NOT NULL DEFAULT 5.00 CHECK (stock_minimo >= 0),
    costo_unitario NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (costo_unitario >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_insumo_sede_nombre UNIQUE (sede_id, nombre)
);

-- 1.4. TABLA: recetas_escandallo
CREATE TABLE IF NOT EXISTS public.recetas_escandallo (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    producto_barra_id UUID NOT NULL REFERENCES public.productos_barra(id) ON DELETE CASCADE,
    insumo_id UUID NOT NULL REFERENCES public.insumos_inventario(id) ON DELETE RESTRICT,
    cantidad_requerida NUMERIC(12, 2) NOT NULL CHECK (cantidad_requerida > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_receta_producto_insumo UNIQUE (producto_barra_id, insumo_id)
);

-- 1.5. TABLA: comandas
CREATE TABLE IF NOT EXISTS public.comandas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fecha TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    nombre_cliente TEXT NOT NULL,
    sede_id UUID NOT NULL REFERENCES public.sedes(id) ON DELETE RESTRICT,
    precio_total NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (precio_total >= 0),
    notas TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 1.6. TABLA: comanda_detalles
CREATE TABLE IF NOT EXISTS public.comanda_detalles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    comanda_id UUID NOT NULL REFERENCES public.comandas(id) ON DELETE CASCADE,
    producto_barra_id UUID NOT NULL REFERENCES public.productos_barra(id) ON DELETE RESTRICT,
    nombre_producto TEXT NOT NULL,
    cantidad NUMERIC(12, 2) NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12, 2) NOT NULL CHECK (precio_unitario >= 0),
    subtotal NUMERIC(12, 2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 1.7. TABLA: kardex_movimientos
CREATE TABLE IF NOT EXISTS public.kardex_movimientos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fecha TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    insumo_id UUID NOT NULL REFERENCES public.insumos_inventario(id) ON DELETE RESTRICT,
    sede_origen_id UUID NOT NULL REFERENCES public.sedes(id) ON DELETE RESTRICT,
    sede_destino_id UUID REFERENCES public.sedes(id) ON DELETE RESTRICT,
    tipo_movimiento TEXT NOT NULL CHECK (
        tipo_movimiento IN (
            'ENTRADA_COMPRA',
            'VENTA_COMANDA',
            'TRASLADO',
            'MERMA',
            'CONSUMO_DUENO',
            'CONSUMO_TRABAJADOR'
        )
    ),
    cantidad NUMERIC(12, 2) NOT NULL CHECK (cantidad > 0),
    beneficiario_o_motivo TEXT,
    referencia_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ==============================================================================
-- 2. SEGURIDAD: ROW LEVEL SECURITY (RLS)
-- ==============================================================================

ALTER TABLE public.sedes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.productos_barra ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.insumos_inventario ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recetas_escandallo ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comandas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comanda_detalles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kardex_movimientos ENABLE ROW LEVEL SECURITY;

-- Políticas para usuarios autenticados (authenticated) y anónimos de acceso local
DO $$ 
DECLARE
    t text;
    tables text[] := ARRAY[
        'sedes', 
        'productos_barra', 
        'insumos_inventario', 
        'recetas_escandallo', 
        'comandas', 
        'comanda_detalles', 
        'kardex_movimientos'
    ];
BEGIN
    FOREACH t IN ARRAY tables LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I_authenticated_all ON public.%I;', t, t);
        EXECUTE format('CREATE POLICY %I_authenticated_all ON public.%I FOR ALL TO authenticated USING (true) WITH CHECK (true);', t, t);
        
        EXECUTE format('DROP POLICY IF EXISTS %I_anon_all ON public.%I;', t, t);
        EXECUTE format('CREATE POLICY %I_anon_all ON public.%I FOR ALL TO anon USING (true) WITH CHECK (true);', t, t);
    END LOOP;
END $$;

-- ==============================================================================
-- 3. FUNCIONES RPC ATÓMICAS OBLIGATORIAS
-- ==============================================================================

-- 3.1. RPC: registrar_comanda_completa
-- Inserta comanda, detalles, calcula precio_total, descuenta insumos y registra kardex
CREATE OR REPLACE FUNCTION public.registrar_comanda_completa(
    p_fecha TIMESTAMPTZ,
    p_nombre_cliente TEXT,
    p_sede_id UUID,
    p_items_json JSONB,
    p_notas TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_comanda_id UUID;
    v_precio_total NUMERIC(12, 2) := 0.00;
    v_item RECORD;
    v_prod RECORD;
    v_receta RECORD;
    v_insumo_id UUID;
    v_cant_item NUMERIC(12, 2);
    v_precio_item NUMERIC(12, 2);
    v_subtotal_item NUMERIC(12, 2);
    v_descuento_cant NUMERIC(12, 2);
BEGIN
    -- Validaciones básicas
    IF p_nombre_cliente IS NULL OR TRIM(p_nombre_cliente) = '' THEN
        RAISE EXCEPTION 'El nombre del cliente no puede estar vacío';
    END IF;

    IF p_items_json IS NULL OR jsonb_array_length(p_items_json) = 0 THEN
        RAISE EXCEPTION 'La comanda debe contener al menos un producto';
    END IF;

    -- Validar sede
    IF NOT EXISTS (SELECT 1 FROM public.sedes WHERE id = p_sede_id) THEN
        RAISE EXCEPTION 'La sede especificada no existe';
    END IF;

    -- 1. Insertar encabezado de comanda
    INSERT INTO public.comandas (
        fecha,
        nombre_cliente,
        sede_id,
        precio_total,
        notas
    ) VALUES (
        COALESCE(p_fecha, timezone('utc'::text, now())),
        TRIM(p_nombre_cliente),
        p_sede_id,
        0.00,
        p_notas
    ) RETURNING id INTO v_comanda_id;

    -- 2. Procesar cada ítem del JSON
    FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items_json) AS (
        producto_barra_id UUID,
        cantidad NUMERIC,
        precio_unitario NUMERIC
    )
    LOOP
        v_cant_item := COALESCE(v_item.cantidad, 0);
        IF v_cant_item <= 0 THEN
            RAISE EXCEPTION 'La cantidad del producto debe ser mayor a 0';
        END IF;

        -- Obtener información del producto
        SELECT * INTO v_prod FROM public.productos_barra WHERE id = v_item.producto_barra_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Producto con ID % no encontrado en catálogo', v_item.producto_barra_id;
        END IF;

        -- Usar precio provisto o el del catálogo
        v_precio_item := COALESCE(v_item.precio_unitario, v_prod.precio_venta);
        v_subtotal_item := v_cant_item * v_precio_item;
        v_precio_total := v_precio_total + v_subtotal_item;

        -- 2.1. Insertar detalle de comanda
        INSERT INTO public.comanda_detalles (
            comanda_id,
            producto_barra_id,
            nombre_producto,
            cantidad,
            precio_unitario
        ) VALUES (
            v_comanda_id,
            v_prod.id,
            v_prod.nombre,
            v_cant_item,
            v_precio_item
        );

        -- 2.2. Descuento de inventario y registro en Kardex
        IF v_prod.es_receta THEN
            -- Caso Receta: Buscar insumos en recetas_escandallo
            FOR v_receta IN 
                SELECT re.insumo_id, re.cantidad_requerida, ii.nombre AS insumo_nombre
                FROM public.recetas_escandallo re
                JOIN public.insumos_inventario ii ON ii.id = re.insumo_id
                WHERE re.producto_barra_id = v_prod.id
            LOOP
                -- Buscar el insumo correspondiente en la sede actual (por ID o por Nombre)
                SELECT id INTO v_insumo_id 
                FROM public.insumos_inventario 
                WHERE sede_id = p_sede_id 
                  AND (id = v_receta.insumo_id OR LOWER(TRIM(nombre)) = LOWER(TRIM(v_receta.insumo_nombre)))
                LIMIT 1;

                IF v_insumo_id IS NOT NULL THEN
                    v_descuento_cant := v_cant_item * v_receta.cantidad_requerida;

                    -- Bloquear y validar stock antes de descontar
                    UPDATE public.insumos_inventario
                    SET stock_actual = stock_actual - v_descuento_cant,
                        updated_at = timezone('utc'::text, now())
                    WHERE id = v_insumo_id
                      AND stock_actual >= v_descuento_cant;

                    IF NOT FOUND THEN
                        RAISE EXCEPTION 'Stock insuficiente para el insumo "%"', v_receta.insumo_nombre;
                    END IF;

                    -- Asentar en kardex
                    INSERT INTO public.kardex_movimientos (
                        fecha,
                        insumo_id,
                        sede_origen_id,
                        tipo_movimiento,
                        cantidad,
                        beneficiario_o_motivo,
                        referencia_id
                    ) VALUES (
                        COALESCE(p_fecha, timezone('utc'::text, now())),
                        v_insumo_id,
                        p_sede_id,
                        'VENTA_COMANDA',
                        v_descuento_cant,
                        'Comanda: ' || TRIM(p_nombre_cliente) || ' | Prep: ' || v_prod.nombre,
                        v_comanda_id
                    );
                END IF;
            END LOOP;
        ELSE
            -- Caso Directo por unidad (ej. Cerveza, Refresco, Botella directa)
            SELECT id INTO v_insumo_id 
            FROM public.insumos_inventario 
            WHERE sede_id = p_sede_id 
              AND LOWER(TRIM(nombre)) = LOWER(TRIM(v_prod.nombre))
            LIMIT 1;

            IF v_insumo_id IS NOT NULL THEN
                v_descuento_cant := v_cant_item;

                -- Bloquear y validar stock antes de descontar
                UPDATE public.insumos_inventario
                SET stock_actual = stock_actual - v_descuento_cant,
                    updated_at = timezone('utc'::text, now())
                WHERE id = v_insumo_id
                  AND stock_actual >= v_descuento_cant;

                IF NOT FOUND THEN
                    RAISE EXCEPTION 'Stock insuficiente para el producto "%"', v_prod.nombre;
                END IF;

                -- Asentar en kardex
                INSERT INTO public.kardex_movimientos (
                    fecha,
                    insumo_id,
                    sede_origen_id,
                    tipo_movimiento,
                    cantidad,
                    beneficiario_o_motivo,
                    referencia_id
                ) VALUES (
                    COALESCE(p_fecha, timezone('utc'::text, now())),
                    v_insumo_id,
                    p_sede_id,
                    'VENTA_COMANDA',
                    v_cant_item,
                    'Comanda: ' || TRIM(p_nombre_cliente) || ' | Producto: ' || v_prod.nombre,
                    v_comanda_id
                );
            END IF;
        END IF;
    END LOOP;

    -- 3. Actualizar total final de la comanda
    UPDATE public.comandas
    SET precio_total = v_precio_total
    WHERE id = v_comanda_id;

    RETURN jsonb_build_object(
        'success', true,
        'comanda_id', v_comanda_id,
        'precio_total', v_precio_total,
        'nombre_cliente', TRIM(p_nombre_cliente)
    );
END;
$$;

-- 3.2. RPC: registrar_traslado_sedes
-- Transfiere stock de sede origen a sede destino y asienta en kardex atómicamente
CREATE OR REPLACE FUNCTION public.registrar_traslado_sedes(
    p_insumo_nombre TEXT,
    p_sede_origen_id UUID,
    p_sede_destino_id UUID,
    p_cantidad NUMERIC,
    p_motivo TEXT DEFAULT 'Traslado inter-sede'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_insumo_origen RECORD;
    v_insumo_destino_id UUID;
    v_unidad_medida TEXT;
    v_costo_unitario NUMERIC(12, 2);
BEGIN
    IF p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad de traslado debe ser mayor a 0';
    END IF;

    IF p_sede_origen_id = p_sede_destino_id THEN
        RAISE EXCEPTION 'La sede origen y la sede destino no pueden ser iguales';
    END IF;

    -- Buscar insumo en origen
    SELECT * INTO v_insumo_origen 
    FROM public.insumos_inventario 
    WHERE sede_id = p_sede_origen_id 
      AND LOWER(TRIM(nombre)) = LOWER(TRIM(p_insumo_nombre))
    FOR UPDATE
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El insumo "%" no existe en la sede de origen', p_insumo_nombre;
    END IF;

    IF v_insumo_origen.stock_actual < p_cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente para trasladar "%". Disponible: %, solicitado: %',
            p_insumo_nombre, v_insumo_origen.stock_actual, p_cantidad;
    END IF;

    -- Descontar stock en sede origen
    UPDATE public.insumos_inventario
    SET stock_actual = stock_actual - p_cantidad,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_insumo_origen.id
      AND stock_actual >= p_cantidad;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El stock cambió mientras se procesaba el traslado';
    END IF;

    -- Buscar o crear insumo en sede destino
    SELECT id INTO v_insumo_destino_id 
    FROM public.insumos_inventario 
    WHERE sede_id = p_sede_destino_id 
      AND LOWER(TRIM(nombre)) = LOWER(TRIM(p_insumo_nombre))
    LIMIT 1;

    IF v_insumo_destino_id IS NULL THEN
        -- Si no existe en destino, crearlo con las mismas propiedades
        INSERT INTO public.insumos_inventario (
            sede_id,
            nombre,
            unidad_medida,
            stock_actual,
            stock_minimo,
            costo_unitario
        ) VALUES (
            p_sede_destino_id,
            v_insumo_origen.nombre,
            v_insumo_origen.unidad_medida,
            p_cantidad,
            v_insumo_origen.stock_minimo,
            v_insumo_origen.costo_unitario
        ) RETURNING id INTO v_insumo_destino_id;
    ELSE
        -- Incrementar stock en destino
        UPDATE public.insumos_inventario
        SET stock_actual = stock_actual + p_cantidad,
            updated_at = timezone('utc'::text, now())
        WHERE id = v_insumo_destino_id;
    END IF;

    -- Registrar movimiento en kardex
    INSERT INTO public.kardex_movimientos (
        fecha,
        insumo_id,
        sede_origen_id,
        sede_destino_id,
        tipo_movimiento,
        cantidad,
        beneficiario_o_motivo
    ) VALUES (
        timezone('utc'::text, now()),
        v_insumo_origen.id,
        p_sede_origen_id,
        p_sede_destino_id,
        'TRASLADO',
        p_cantidad,
        COALESCE(p_motivo, 'Traslado inter-sede')
    );

    RETURN jsonb_build_object(
        'success', true,
        'mensaje', 'Traslado realizado exitosamente',
        'insumo', v_insumo_origen.nombre,
        'cantidad', p_cantidad
    );
END;
$$;

-- 3.3. RPC: registrar_merma
-- Descuenta stock por pérdida/rotura/deterioro y asienta en kardex
CREATE OR REPLACE FUNCTION public.registrar_merma(
    p_insumo_id UUID,
    p_sede_id UUID,
    p_cantidad NUMERIC,
    p_motivo TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_insumo RECORD;
BEGIN
    IF p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad de merma debe ser mayor a 0';
    END IF;

    SELECT * INTO v_insumo
    FROM public.insumos_inventario
    WHERE id = p_insumo_id AND sede_id = p_sede_id
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Insumo no encontrado en la sede indicada';
    END IF;

    -- Descontar stock
    IF v_insumo.stock_actual < p_cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente. Disponible: %, solicitado: %',
            v_insumo.stock_actual, p_cantidad;
    END IF;

    UPDATE public.insumos_inventario
    SET stock_actual = stock_actual - p_cantidad,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_insumo_id
      AND stock_actual >= p_cantidad;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El stock cambió mientras se procesaba la merma';
    END IF;

    -- Registrar en Kardex
    INSERT INTO public.kardex_movimientos (
        fecha,
        insumo_id,
        sede_origen_id,
        tipo_movimiento,
        cantidad,
        beneficiario_o_motivo
    ) VALUES (
        timezone('utc'::text, now()),
        p_insumo_id,
        p_sede_id,
        'MERMA',
        p_cantidad,
        COALESCE(p_motivo, 'Merma / Rotura')
    );

    RETURN jsonb_build_object('success', true, 'mensaje', 'Merma registrada exitosamente');
END;
$$;

-- 3.4. RPC: registrar_consumo_interno
-- Registra consumos de Dueño o Trabajadores con descuento de stock atómico
CREATE OR REPLACE FUNCTION public.registrar_consumo_interno(
    p_insumo_id UUID,
    p_sede_id UUID,
    p_cantidad NUMERIC,
    p_tipo TEXT,
    p_beneficiario TEXT,
    p_motivo TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_insumo RECORD;
    v_tipo_norm TEXT;
BEGIN
    IF p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad debe ser mayor a 0';
    END IF;

    v_tipo_norm := UPPER(TRIM(p_tipo));
    IF v_tipo_norm NOT IN ('CONSUMO_DUENO', 'CONSUMO_TRABAJADOR') THEN
        RAISE EXCEPTION 'Tipo de consumo no válido. Debe ser CONSUMO_DUENO o CONSUMO_TRABAJADOR';
    END IF;

    SELECT * INTO v_insumo
    FROM public.insumos_inventario
    WHERE id = p_insumo_id AND sede_id = p_sede_id
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Insumo no encontrado en la sede indicada';
    END IF;

    IF v_insumo.stock_actual < p_cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente. Disponible: %, solicitado: %',
            v_insumo.stock_actual, p_cantidad;
    END IF;

    -- Descontar stock
    UPDATE public.insumos_inventario
    SET stock_actual = stock_actual - p_cantidad,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_insumo_id
      AND stock_actual >= p_cantidad;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El stock cambió mientras se procesaba el consumo';
    END IF;

    -- Registrar en Kardex
    INSERT INTO public.kardex_movimientos (
        fecha,
        insumo_id,
        sede_origen_id,
        tipo_movimiento,
        cantidad,
        beneficiario_o_motivo
    ) VALUES (
        timezone('utc'::text, now()),
        p_insumo_id,
        p_sede_id,
        v_tipo_norm,
        p_cantidad,
        'Beneficiario: ' || COALESCE(p_beneficiario, 'No especificado') || COALESCE(' | ' || p_motivo, '')
    );

    RETURN jsonb_build_object('success', true, 'mensaje', 'Consumo interno registrado exitosamente');
END;
$$;

-- 3.5. RPC: registrar_entrada_compra
-- Registra abastecimiento/compra directa de insumo, actualiza costo y stock
CREATE OR REPLACE FUNCTION public.registrar_entrada_compra(
    p_insumo_id UUID,
    p_sede_id UUID,
    p_cantidad NUMERIC,
    p_costo_unitario NUMERIC,
    p_proveedor_o_motivo TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad debe ser mayor a 0';
    END IF;

    -- Actualizar stock y costo
    UPDATE public.insumos_inventario
    SET stock_actual = stock_actual + p_cantidad,
        costo_unitario = CASE WHEN p_costo_unitario > 0 THEN p_costo_unitario ELSE costo_unitario END,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_insumo_id AND sede_id = p_sede_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Insumo no encontrado en la sede indicada';
    END IF;

    -- Asentar en Kardex
    INSERT INTO public.kardex_movimientos (
        fecha,
        insumo_id,
        sede_origen_id,
        tipo_movimiento,
        cantidad,
        beneficiario_o_motivo
    ) VALUES (
        timezone('utc'::text, now()),
        p_insumo_id,
        p_sede_id,
        'ENTRADA_COMPRA',
        p_cantidad,
        COALESCE(p_proveedor_o_motivo, 'Entrada por compra')
    );

    RETURN jsonb_build_object('success', true, 'mensaje', 'Entrada de compra registrada exitosamente');
END;
$$;

-- 3.6. RPC: registrar_movimiento_hielo
-- Gestiona panel dual y movimientos de bolsas de hielo (compra, merma o traslado)
CREATE OR REPLACE FUNCTION public.registrar_movimiento_hielo(
    p_sede_id UUID,
    p_tipo_movimiento TEXT,
    p_cantidad NUMERIC,
    p_motivo TEXT,
    p_sede_destino_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_insumo_id UUID;
    v_tipo TEXT := UPPER(TRIM(p_tipo_movimiento));
BEGIN
    IF p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad debe ser mayor a 0';
    END IF;

    -- Buscar o asegurar el insumo 'Bolsa de Hielo' en la sede
    SELECT id INTO v_insumo_id 
    FROM public.insumos_inventario 
    WHERE sede_id = p_sede_id AND (LOWER(TRIM(nombre)) = 'bolsa de hielo' OR unidad_medida = 'bolsa_hielo')
    LIMIT 1;

    IF v_insumo_id IS NULL THEN
        INSERT INTO public.insumos_inventario (
            sede_id, nombre, unidad_medida, stock_actual, stock_minimo, costo_unitario
        ) VALUES (
            p_sede_id, 'Bolsa de Hielo', 'bolsa_hielo', 0.00, 5.00, 1.50
        ) RETURNING id INTO v_insumo_id;
    END IF;

    IF v_tipo = 'COMPRA' OR v_tipo = 'ENTRADA_COMPRA' THEN
        RETURN public.registrar_entrada_compra(v_insumo_id, p_sede_id, p_cantidad, 1.50, p_motivo);
    ELSIF v_tipo = 'MERMA' OR v_tipo = 'DESHIELO' THEN
        RETURN public.registrar_merma(v_insumo_id, p_sede_id, p_cantidad, COALESCE(p_motivo, 'Deshielo / Merma de hielo'));
    ELSIF v_tipo = 'TRASLADO' THEN
        IF p_sede_destino_id IS NULL THEN
            RAISE EXCEPTION 'Debe especificar la sede de destino para el traslado de hielo';
        END IF;
        RETURN public.registrar_traslado_sedes('Bolsa de Hielo', p_sede_id, p_sede_destino_id, p_cantidad, p_motivo);
    ELSE
        RAISE EXCEPTION 'Tipo de movimiento de hielo no reconocido';
    END IF;
END;
$$;

-- ==============================================================================
-- 4. DATOS INICIALES SEMILLA (SEED DATA)
-- ==============================================================================

-- 4.1. Sedes Oficiales
INSERT INTO public.sedes (nombre, es_principal)
VALUES 
    ('Sede Principal', true),
    ('Sede Secundaria', false)
ON CONFLICT (nombre) DO UPDATE SET es_principal = EXCLUDED.es_principal;

-- 4.2. Insumos Iniciales para Sede Principal y Secundaria
DO $$
DECLARE
    v_sede_prin UUID;
    v_sede_sec UUID;
    v_hielo_id UUID;
    v_ron_id UUID;
    v_coca_id UUID;
    v_limon_id UUID;
    v_polar_id UUID;
    v_prod_cuba UUID;
    v_prod_polar UUID;
BEGIN
    SELECT id INTO v_sede_prin FROM public.sedes WHERE nombre = 'Sede Principal' LIMIT 1;
    SELECT id INTO v_sede_sec FROM public.sedes WHERE nombre = 'Sede Secundaria' LIMIT 1;

    -- Insumos Sede Principal
    INSERT INTO public.insumos_inventario (sede_id, nombre, unidad_medida, stock_actual, stock_minimo, costo_unitario)
    VALUES
        (v_sede_prin, 'Bolsa de Hielo', 'bolsa_hielo', 25.00, 8.00, 1.50),
        (v_sede_prin, 'Polar Pilsen', 'unidad', 72.00, 24.00, 1.00),
        (v_sede_prin, 'Polar Light', 'unidad', 60.00, 20.00, 1.00),
        (v_sede_prin, 'Ron Santa Teresa Gran Reserva', 'ml', 2250.00, 750.00, 0.02),
        (v_sede_prin, 'Refresco Coca Cola 2L', 'ml', 6000.00, 2000.00, 0.001),
        (v_sede_prin, 'Limón Tahití', 'gr', 3000.00, 1000.00, 0.003),
        (v_sede_prin, 'Whisky Black Label 12 Años', 'ml', 1500.00, 750.00, 0.04),
        (v_sede_prin, 'Vodka Absolut', 'ml', 1500.00, 750.00, 0.03),
        (v_sede_prin, 'Jugo de Naranja Natural', 'ml', 4000.00, 1000.00, 0.002),
        (v_sede_prin, 'Agua Mineral 500ml', 'unidad', 36.00, 12.00, 0.50)
    ON CONFLICT (sede_id, nombre) DO NOTHING;

    -- Insumos Sede Secundaria (Respaldo)
    INSERT INTO public.insumos_inventario (sede_id, nombre, unidad_medida, stock_actual, stock_minimo, costo_unitario)
    VALUES
        (v_sede_sec, 'Bolsa de Hielo', 'bolsa_hielo', 40.00, 10.00, 1.50),
        (v_sede_sec, 'Polar Pilsen', 'unidad', 120.00, 48.00, 1.00),
        (v_sede_sec, 'Polar Light', 'unidad', 96.00, 36.00, 1.00)
    ON CONFLICT (sede_id, nombre) DO NOTHING;

    -- 4.3. Productos de Barra
    INSERT INTO public.productos_barra (nombre, categoria, precio_venta, es_receta, activo)
    VALUES
        ('Polar Pilsen', 'Cervezas', 1.50, false, true),
        ('Polar Light', 'Cervezas', 1.50, false, true),
        ('Cuba Libre', 'Cocteles', 4.00, true, true),
        ('Mojito Tradicional', 'Cocteles', 5.00, true, true),
        ('Trago Ron Santa Teresa', 'Licores', 3.50, true, true),
        ('Trago Whisky Black Label', 'Licores', 6.00, true, true),
        ('Jugo de Naranja', 'Jugos', 2.50, false, true),
        ('Agua Mineral', 'No Alcoholicas', 1.00, false, true)
    ON CONFLICT (nombre) DO UPDATE SET 
        precio_venta = EXCLUDED.precio_venta,
        categoria = EXCLUDED.categoria,
        es_receta = EXCLUDED.es_receta;

    -- 4.4. Recetas de Escandallo para Cocteles
    SELECT id INTO v_prod_cuba FROM public.productos_barra WHERE nombre = 'Cuba Libre' LIMIT 1;
    SELECT id INTO v_ron_id FROM public.insumos_inventario WHERE sede_id = v_sede_prin AND nombre = 'Ron Santa Teresa Gran Reserva' LIMIT 1;
    SELECT id INTO v_coca_id FROM public.insumos_inventario WHERE sede_id = v_sede_prin AND nombre = 'Refresco Coca Cola 2L' LIMIT 1;
    SELECT id INTO v_limon_id FROM public.insumos_inventario WHERE sede_id = v_sede_prin AND nombre = 'Limón Tahití' LIMIT 1;

    IF v_prod_cuba IS NOT NULL AND v_ron_id IS NOT NULL AND v_coca_id IS NOT NULL THEN
        INSERT INTO public.recetas_escandallo (producto_barra_id, insumo_id, cantidad_requerida)
        VALUES
            (v_prod_cuba, v_ron_id, 50.00),   -- 50 ml ron
            (v_prod_cuba, v_coca_id, 150.00), -- 150 ml refresco
            (v_prod_cuba, v_limon_id, 20.00)  -- 20 gr limón
        ON CONFLICT (producto_barra_id, insumo_id) DO UPDATE SET
            cantidad_requerida = EXCLUDED.cantidad_requerida;
    END IF;

    -- Receta para Trago Ron Santa Teresa
    SELECT id INTO v_prod_polar FROM public.productos_barra WHERE nombre = 'Trago Ron Santa Teresa' LIMIT 1;
    IF v_prod_polar IS NOT NULL AND v_ron_id IS NOT NULL THEN
        INSERT INTO public.recetas_escandallo (producto_barra_id, insumo_id, cantidad_requerida)
        VALUES
            (v_prod_polar, v_ron_id, 50.00) -- 50 ml servicio
        ON CONFLICT (producto_barra_id, insumo_id) DO UPDATE SET
            cantidad_requerida = EXCLUDED.cantidad_requerida;
    END IF;

END $$;
