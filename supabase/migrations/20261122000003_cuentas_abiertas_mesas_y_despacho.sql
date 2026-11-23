-- ==============================================================================
-- MIGRACIÓN: CUENTAS ABIERTAS (MESAS ABIERTAS), DESPACHO POR RONDAS Y CIERRE
-- Archivo: supabase/migrations/20261122000003_cuentas_abiertas_mesas_y_despacho.sql
-- ==============================================================================

-- 1. Ampliar columnas en public.comandas
ALTER TABLE public.comandas ADD COLUMN IF NOT EXISTS estado TEXT NOT NULL DEFAULT 'REGISTRADA';
ALTER TABLE public.comandas ADD COLUMN IF NOT EXISTS mesa TEXT NOT NULL DEFAULT 'BARRA';
ALTER TABLE public.comandas ADD COLUMN IF NOT EXISTS mesero TEXT DEFAULT 'ILARIO MEDINA';
ALTER TABLE public.comandas ADD COLUMN IF NOT EXISTS ronda INT NOT NULL DEFAULT 1;
ALTER TABLE public.comandas ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now());

-- 2. Ampliar columna ronda en public.comanda_detalles
ALTER TABLE public.comanda_detalles ADD COLUMN IF NOT EXISTS ronda INT NOT NULL DEFAULT 1;

-- 3. Índices de rendimiento
CREATE INDEX IF NOT EXISTS idx_comandas_estado ON public.comandas(estado);
CREATE INDEX IF NOT EXISTS idx_comandas_sede_estado ON public.comandas(sede_id, estado);

-- 4. RPC: despachar_comanda_ronda
-- Permite iniciar una cuenta abierta o despachar una nueva ronda a una cuenta existente,
-- descontando de inmediato los insumos de la ronda del inventario y registrando kardex atómicamente.
CREATE OR REPLACE FUNCTION public.despachar_comanda_ronda(
    p_comanda_id UUID DEFAULT NULL,
    p_nombre_cliente TEXT DEFAULT 'Cliente Barra',
    p_mesa TEXT DEFAULT 'BARRA',
    p_mesero TEXT DEFAULT 'ILARIO MEDINA',
    p_sede_id UUID DEFAULT NULL,
    p_items_json JSONB DEFAULT '[]'::jsonb,
    p_notas TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_comanda_id UUID := p_comanda_id;
    v_numero_ticket TEXT;
    v_ronda INT := 1;
    v_precio_total_ronda NUMERIC(12, 2) := 0.00;
    v_precio_total_acumulado NUMERIC(12, 2) := 0.00;
    v_item RECORD;
    v_prod RECORD;
    v_receta RECORD;
    v_insumo_id UUID;
    v_cant_item NUMERIC(12, 2);
    v_precio_item NUMERIC(12, 2);
    v_subtotal_item NUMERIC(12, 2);
    v_descuento_cant NUMERIC(12, 2);
    v_sede_id UUID := p_sede_id;
    v_nombre_cliente TEXT := COALESCE(NULLIF(TRIM(p_nombre_cliente), ''), 'Cliente Barra');
    v_mesa TEXT := COALESCE(NULLIF(TRIM(p_mesa), ''), 'BARRA');
    v_mesero TEXT := COALESCE(NULLIF(TRIM(p_mesero), ''), 'ILARIO MEDINA');
BEGIN
    IF p_items_json IS NULL OR jsonb_array_length(p_items_json) = 0 THEN
        RAISE EXCEPTION 'Debe agregar al menos un producto para despachar';
    END IF;

    -- Resolver sede si viene nula
    IF v_sede_id IS NULL THEN
        SELECT id INTO v_sede_id FROM public.sedes WHERE es_principal = true LIMIT 1;
        IF v_sede_id IS NULL THEN
            SELECT id INTO v_sede_id FROM public.sedes LIMIT 1;
        END IF;
    END IF;

    -- Validar o recuperar comanda existente
    IF v_comanda_id IS NOT NULL THEN
        SELECT id, numero_ticket, ronda, precio_total, nombre_cliente, mesa, mesero
        INTO v_comanda_id, v_numero_ticket, v_ronda, v_precio_total_acumulado, v_nombre_cliente, v_mesa, v_mesero
        FROM public.comandas
        WHERE id = v_comanda_id AND estado = 'ABIERTA';

        IF NOT FOUND THEN
            RAISE EXCEPTION 'No se encontró la comanda abierta especificada';
        END IF;

        -- Siguiente ronda
        v_ronda := COALESCE(v_ronda, 1) + 1;

        -- Actualizar datos en comanda
        UPDATE public.comandas
        SET ronda = v_ronda,
            mesa = COALESCE(NULLIF(TRIM(p_mesa), ''), v_mesa),
            mesero = COALESCE(NULLIF(TRIM(p_mesero), ''), v_mesero),
            notas = CASE 
                WHEN p_notas IS NOT NULL AND TRIM(p_notas) <> '' THEN 
                    COALESCE(notas || E'\n[Ronda ' || v_ronda || ']: ' || TRIM(p_notas), '[Ronda ' || v_ronda || ']: ' || TRIM(p_notas))
                ELSE notas
            END,
            updated_at = timezone('utc'::text, now())
        WHERE id = v_comanda_id;
    ELSE
        -- Nueva comanda abierta
        v_numero_ticket := 'CMD-' || to_char(timezone('utc'::text, now()), 'YYYYMMDD') || '-' || UPPER(SUBSTRING(gen_random_uuid()::text FROM 1 FOR 6));
        v_ronda := 1;

        INSERT INTO public.comandas (
            fecha,
            nombre_cliente,
            cliente,
            sede_id,
            mesa,
            mesero,
            ronda,
            estado,
            precio_total,
            total,
            subtotal,
            notas,
            numero_ticket
        ) VALUES (
            timezone('utc'::text, now()),
            v_nombre_cliente,
            v_nombre_cliente,
            v_sede_id,
            v_mesa,
            v_mesero,
            1,
            'ABIERTA',
            0.00,
            0.00,
            0.00,
            CASE WHEN p_notas IS NOT NULL AND TRIM(p_notas) <> '' THEN '[Ronda 1]: ' || TRIM(p_notas) ELSE NULL END,
            v_numero_ticket
        ) RETURNING id INTO v_comanda_id;
    END IF;

    -- Procesar ítems de la ronda
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

        SELECT * INTO v_prod FROM public.productos_barra WHERE id = v_item.producto_barra_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Producto con ID % no encontrado en catálogo', v_item.producto_barra_id;
        END IF;

        v_precio_item := COALESCE(v_item.precio_unitario, v_prod.precio_venta);
        v_subtotal_item := v_cant_item * v_precio_item;
        v_precio_total_ronda := v_precio_total_ronda + v_subtotal_item;

        -- Insertar detalle de comanda con el número de ronda
        INSERT INTO public.comanda_detalles (
            comanda_id,
            producto_barra_id,
            nombre_producto,
            cantidad,
            precio_unitario,
            ronda
        ) VALUES (
            v_comanda_id,
            v_prod.id,
            v_prod.nombre,
            v_cant_item,
            v_precio_item,
            v_ronda
        );

        -- Descontar inventario y registrar kardex
        IF v_prod.es_receta THEN
            FOR v_receta IN 
                SELECT re.insumo_id, re.cantidad_requerida, ii.nombre AS insumo_nombre
                FROM public.recetas_escandallo re
                JOIN public.insumos_inventario ii ON ii.id = re.insumo_id
                WHERE re.producto_barra_id = v_prod.id
            LOOP
                SELECT id INTO v_insumo_id 
                FROM public.insumos_inventario 
                WHERE sede_id = v_sede_id 
                  AND (id = v_receta.insumo_id OR LOWER(TRIM(nombre)) = LOWER(TRIM(v_receta.insumo_nombre)))
                LIMIT 1;

                IF v_insumo_id IS NOT NULL THEN
                    v_descuento_cant := v_cant_item * v_receta.cantidad_requerida;

                    UPDATE public.insumos_inventario
                    SET stock_actual = stock_actual - v_descuento_cant,
                        updated_at = timezone('utc'::text, now())
                    WHERE id = v_insumo_id
                      AND stock_actual >= v_descuento_cant;

                    IF NOT FOUND THEN
                        RAISE EXCEPTION 'Stock insuficiente para el insumo "%"', v_receta.insumo_nombre;
                    END IF;

                    INSERT INTO public.kardex_movimientos (
                        fecha,
                        insumo_id,
                        sede_origen_id,
                        tipo_movimiento,
                        cantidad,
                        beneficiario_o_motivo,
                        referencia_id
                    ) VALUES (
                        timezone('utc'::text, now()),
                        v_insumo_id,
                        v_sede_id,
                        'VENTA_COMANDA',
                        v_descuento_cant,
                        'Despacho: ' || v_nombre_cliente || ' [Ronda ' || v_ronda || '] | Prep: ' || v_prod.nombre || ' | Ticket: ' || v_numero_ticket,
                        v_comanda_id
                    );
                END IF;
            END LOOP;
        ELSE
            SELECT id INTO v_insumo_id 
            FROM public.insumos_inventario 
            WHERE sede_id = v_sede_id 
              AND (
                  LOWER(TRIM(nombre)) = LOWER(TRIM(v_prod.nombre))
                  OR LOWER(TRIM(nombre)) = LOWER(TRIM(REPLACE(REPLACE(v_prod.nombre, 'Cerveza ', ''), 'cerveza ', '')))
                  OR LOWER(TRIM(nombre)) = LOWER(TRIM(REPLACE(REPLACE(REPLACE(v_prod.nombre, 'Cerveza ', ''), 'cerveza ', ''), 'Ligth', 'Light')))
                  OR LOWER(TRIM(nombre)) = LOWER(TRIM(v_prod.nombre)) || ' (u)'
                  OR LOWER(TRIM(nombre)) = 'cerveza ' || LOWER(TRIM(REPLACE(REPLACE(v_prod.nombre, 'Cerveza ', ''), 'cerveza ', ''))) || ' (u)'
              )
            ORDER BY 
              (LOWER(TRIM(nombre)) = LOWER(TRIM(v_prod.nombre))) DESC,
              (LOWER(TRIM(nombre)) = LOWER(TRIM(REPLACE(REPLACE(v_prod.nombre, 'Cerveza ', ''), 'cerveza ', '')))) DESC,
              stock_actual DESC
            LIMIT 1;

            IF v_insumo_id IS NOT NULL THEN
                v_descuento_cant := v_cant_item;

                UPDATE public.insumos_inventario
                SET stock_actual = stock_actual - v_descuento_cant,
                    updated_at = timezone('utc'::text, now())
                WHERE id = v_insumo_id
                  AND stock_actual >= v_descuento_cant;

                IF NOT FOUND THEN
                    RAISE EXCEPTION 'Stock insuficiente para el producto "%"', v_prod.nombre;
                END IF;

                INSERT INTO public.kardex_movimientos (
                    fecha,
                    insumo_id,
                    sede_origen_id,
                    tipo_movimiento,
                    cantidad,
                    beneficiario_o_motivo,
                    referencia_id
                ) VALUES (
                    timezone('utc'::text, now()),
                    v_insumo_id,
                    v_sede_id,
                    'VENTA_COMANDA',
                    v_cant_item,
                    'Despacho: ' || v_nombre_cliente || ' [Ronda ' || v_ronda || '] | Producto: ' || v_prod.nombre || ' | Ticket: ' || v_numero_ticket,
                    v_comanda_id
                );
            END IF;
        END IF;
    END LOOP;

    -- Actualizar acumulado de comanda
    UPDATE public.comandas
    SET precio_total = precio_total + v_precio_total_ronda,
        total = total + v_precio_total_ronda,
        subtotal = subtotal + v_precio_total_ronda,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_comanda_id
    RETURNING precio_total INTO v_precio_total_acumulado;

    RETURN jsonb_build_object(
        'success', true,
        'comanda_id', v_comanda_id,
        'numero_ticket', v_numero_ticket,
        'nombre_cliente', v_nombre_cliente,
        'mesa', v_mesa,
        'mesero', v_mesero,
        'ronda', v_ronda,
        'total_ronda', v_precio_total_ronda,
        'precio_total_acumulado', v_precio_total_acumulado
    );
END;
$$;

-- 5. RPC: cerrar_comanda_abierta
-- Cierra y registra definitivamente la comanda abierta cuando el cliente cancela la cuenta
CREATE OR REPLACE FUNCTION public.cerrar_comanda_abierta(
    p_comanda_id UUID,
    p_metodo_pago TEXT DEFAULT 'EFECTIVO_USD',
    p_notas TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_comanda RECORD;
BEGIN
    SELECT * INTO v_comanda FROM public.comandas WHERE id = p_comanda_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Comanda no encontrada';
    END IF;

    UPDATE public.comandas
    SET estado = 'REGISTRADA',
        metodo_pago = COALESCE(p_metodo_pago, metodo_pago, 'EFECTIVO_USD'),
        notas = CASE 
            WHEN p_notas IS NOT NULL AND TRIM(p_notas) <> '' THEN 
                COALESCE(notas || E'\n[Cierre]: ' || TRIM(p_notas), TRIM(p_notas))
            ELSE notas 
        END,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_comanda_id;

    RETURN jsonb_build_object(
        'success', true,
        'comanda_id', p_comanda_id,
        'numero_ticket', v_comanda.numero_ticket,
        'nombre_cliente', v_comanda.nombre_cliente,
        'mesa', v_comanda.mesa,
        'mesero', v_comanda.mesero,
        'precio_total', v_comanda.precio_total,
        'estado', 'REGISTRADA'
    );
END;
$$;
