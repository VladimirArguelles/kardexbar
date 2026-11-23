-- ==============================================================================
-- Migración: 20261122000005_fix_fecha_timezone_and_eligia.sql
-- Propósito:
--   1. Corregir fecha de comanda al día local operativo (America/Caracas UTC-4).
--   2. Asegurar que despachar_comanda_ronda use fecha local para tickets y fecha.
-- ==============================================================================

UPDATE public.comandas
SET fecha = '2026-11-22'
WHERE id = '42514792-16f3-4475-9ff7-57dcc66bd694';

CREATE OR REPLACE FUNCTION public.despachar_comanda_ronda(
    p_comanda_id UUID DEFAULT NULL,
    p_nombre_cliente TEXT DEFAULT NULL,
    p_mesa TEXT DEFAULT 'BARRA',
    p_mesero TEXT DEFAULT 'ILARIO MEDINA',
    p_sede_id UUID DEFAULT NULL,
    p_items_json JSONB DEFAULT '[]'::jsonb,
    p_notas TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_comanda_id UUID := p_comanda_id;
    v_sede_id UUID := p_sede_id;
    v_numero_ticket TEXT;
    v_ronda INT := 1;
    v_item RECORD;
    v_prod RECORD;
    v_receta RECORD;
    v_insumo_id UUID;
    v_cant_item NUMERIC(12, 2);
    v_precio_item NUMERIC(12, 2);
    v_subtotal_item NUMERIC(12, 2);
    v_descuento_cant NUMERIC(12, 2);
    v_multiplicador NUMERIC(12, 2);
    v_nombre_final TEXT;
    v_nombre_cerveza_busqueda TEXT;
    v_precio_total_ronda NUMERIC(12, 2) := 0.00;
    v_fecha_local DATE;
BEGIN
    v_fecha_local := (timezone('America/Caracas', now()))::date;

    IF (p_nombre_cliente IS NULL OR TRIM(p_nombre_cliente) = '') AND v_comanda_id IS NULL THEN
        RAISE EXCEPTION 'El nombre del cliente no puede estar vacío para una cuenta nueva';
    END IF;

    IF p_items_json IS NULL OR jsonb_array_length(p_items_json) = 0 THEN
        RAISE EXCEPTION 'La ronda debe contener al menos un producto a despachar';
    END IF;

    IF v_comanda_id IS NOT NULL THEN
        SELECT id, sede_id, numero_ticket, (COALESCE(ronda, 1) + 1)
        INTO v_comanda_id, v_sede_id, v_numero_ticket, v_ronda
        FROM public.comandas
        WHERE id = v_comanda_id AND estado = 'ABIERTA';

        IF NOT FOUND THEN
            RAISE EXCEPTION 'No se encontró la comanda abierta con ID %', p_comanda_id;
        END IF;

        UPDATE public.comandas
        SET ronda = v_ronda,
            updated_at = timezone('utc'::text, now()),
            notas = CASE 
                WHEN p_notas IS NOT NULL AND TRIM(p_notas) <> '' THEN 
                    COALESCE(notas || E'\n', '') || '[Ronda ' || v_ronda || ']: ' || TRIM(p_notas)
                ELSE notas 
            END
        WHERE id = v_comanda_id;
    ELSE
        IF NOT EXISTS (SELECT 1 FROM public.sedes WHERE id = v_sede_id) THEN
            RAISE EXCEPTION 'La sede especificada no existe';
        END IF;

        v_numero_ticket := 'CMD-' || to_char(v_fecha_local, 'YYYYMMDD') || '-' || UPPER(SUBSTRING(gen_random_uuid()::text FROM 1 FOR 6));

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
            v_fecha_local,
            TRIM(p_nombre_cliente),
            TRIM(p_nombre_cliente),
            v_sede_id,
            COALESCE(NULLIF(TRIM(p_mesa), ''), 'BARRA'),
            COALESCE(NULLIF(TRIM(p_mesero), ''), 'ILARIO MEDINA'),
            1,
            'ABIERTA',
            0.00,
            0.00,
            0.00,
            CASE WHEN p_notas IS NOT NULL AND TRIM(p_notas) <> '' THEN '[Ronda 1]: ' || TRIM(p_notas) ELSE NULL END,
            v_numero_ticket
        ) RETURNING id INTO v_comanda_id;
    END IF;

    FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items_json) AS (
        producto_barra_id UUID,
        cantidad NUMERIC,
        precio_unitario NUMERIC,
        nombre_producto TEXT
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

        v_nombre_final := COALESCE(NULLIF(TRIM(v_item.nombre_producto), ''), v_prod.nombre);

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
            v_nombre_final,
            v_cant_item,
            v_precio_item,
            v_ronda
        );

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
                        RAISE EXCEPTION 'Stock insuficiente para el insumo "%" de la receta en la sede', v_receta.insumo_nombre;
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
                        'Ronda ' || v_ronda || ' | ' || v_nombre_final || ' (Receta) | Ticket: ' || v_numero_ticket,
                        v_comanda_id
                    );
                END IF;
            END LOOP;
        ELSE
            v_multiplicador := 1.0;
            IF v_nombre_final ILIKE '%Promo Balde%' OR v_nombre_final ILIKE '%Balde%12%' THEN
                v_multiplicador := 12.0;
            ELSIF v_nombre_final ILIKE '%Balde%10%' THEN
                v_multiplicador := 10.0;
            ELSIF v_nombre_final ILIKE '%Caja%Zulia%' OR v_nombre_final ILIKE '%Caja%Polar%' THEN
                v_multiplicador := 36.0;
            ELSIF v_nombre_final ILIKE '%½ Caja%' THEN
                v_multiplicador := 18.0;
            END IF;

            v_nombre_cerveza_busqueda := v_nombre_final;
            IF v_nombre_final ~ '\((.*?)\)' THEN
                v_nombre_cerveza_busqueda := substring(v_nombre_final FROM '\((.*?)\)');
                v_nombre_cerveza_busqueda := REPLACE(v_nombre_cerveza_busqueda, '12x', '');
                v_nombre_cerveza_busqueda := REPLACE(v_nombre_cerveza_busqueda, '10x', '');
                v_nombre_cerveza_busqueda := TRIM(v_nombre_cerveza_busqueda);
            END IF;

            SELECT id INTO v_insumo_id 
            FROM public.insumos_inventario 
            WHERE sede_id = v_sede_id 
              AND (
                  LOWER(TRIM(nombre)) = LOWER(TRIM(v_nombre_cerveza_busqueda))
                  OR LOWER(TRIM(nombre)) = LOWER(TRIM(v_prod.nombre))
                  OR LOWER(TRIM(nombre)) = LOWER(TRIM(REPLACE(REPLACE(v_nombre_cerveza_busqueda, 'Cerveza ', ''), 'cerveza ', '')))
                  OR LOWER(TRIM(nombre)) = LOWER(TRIM(REPLACE(REPLACE(v_prod.nombre, 'Cerveza ', ''), 'cerveza ', '')))
                  OR LOWER(TRIM(nombre)) = LOWER(TRIM(REPLACE(REPLACE(REPLACE(v_nombre_cerveza_busqueda, 'Cerveza ', ''), 'cerveza ', ''), 'Ligth', 'Light')))
                  OR LOWER(TRIM(nombre)) = LOWER(TRIM(v_nombre_cerveza_busqueda)) || ' (u)'
                  OR (v_nombre_final ILIKE '%Promo Balde%' AND LOWER(TRIM(nombre)) = 'polar light')
              )
            ORDER BY 
              (LOWER(TRIM(nombre)) = LOWER(TRIM(v_nombre_cerveza_busqueda))) DESC,
              (LOWER(TRIM(nombre)) = LOWER(TRIM(v_prod.nombre))) DESC,
              stock_actual DESC
            LIMIT 1;

            IF v_insumo_id IS NOT NULL THEN
                v_descuento_cant := v_cant_item * v_multiplicador;

                UPDATE public.insumos_inventario
                SET stock_actual = stock_actual - v_descuento_cant,
                    updated_at = timezone('utc'::text, now())
                WHERE id = v_insumo_id
                  AND stock_actual >= v_descuento_cant;

                IF NOT FOUND THEN
                    RAISE EXCEPTION 'Stock insuficiente para "%" (% uds requeridas) en la sede seleccionada', v_nombre_final, v_descuento_cant;
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
                    'Ronda ' || v_ronda || ' | ' || v_nombre_final || ' (' || v_descuento_cant || ' uds) | Ticket: ' || v_numero_ticket,
                    v_comanda_id
                );
            END IF;
        END IF;
    END LOOP;

    UPDATE public.comandas
    SET precio_total = precio_total + v_precio_total_ronda,
        total = total + v_precio_total_ronda,
        subtotal = subtotal + v_precio_total_ronda,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_comanda_id;

    RETURN jsonb_build_object(
        'success', true,
        'comanda_id', v_comanda_id,
        'numero_ticket', v_numero_ticket,
        'ronda', v_ronda,
        'total_ronda', v_precio_total_ronda
    );
END;
$$;
