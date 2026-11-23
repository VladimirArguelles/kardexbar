-- ==============================================================================
-- MIGRACIÓN: CORRECCIÓN DE RESTRICCIÓN NUMERO_TICKET EN COMANDAS Y ATOMICIDAD RPC
-- Archivo: supabase/migrations/20261122000002_fix_comandas_numero_ticket_y_descuento_cervezas.sql
-- ==============================================================================

-- 1. Asegurar que numero_ticket permita valores nulos o tenga valor por defecto autogenerado
ALTER TABLE public.comandas ALTER COLUMN numero_ticket DROP NOT NULL;
ALTER TABLE public.comandas ALTER COLUMN numero_ticket SET DEFAULT ('CMD-' || to_char(CURRENT_DATE, 'YYYYMMDD') || '-' || UPPER(SUBSTRING(gen_random_uuid()::text FROM 1 FOR 6)));

-- 2. Actualizar registros antiguos de comandas que pudieran tener numero_ticket nulo si existieran
UPDATE public.comandas 
SET numero_ticket = 'CMD-' || to_char(COALESCE(fecha::date, CURRENT_DATE), 'YYYYMMDD') || '-' || UPPER(SUBSTRING(id::text FROM 1 FOR 6))
WHERE numero_ticket IS NULL;

-- 3. Actualizar la función atómica registrar_comanda_completa
-- Garantiza:
--   a) Generación explícita de numero_ticket y almacenamiento en public.comandas.
--   b) Descuento automático en insumos_inventario para cervezas y productos directos,
--      resolviendo variaciones de nombres (ej. 'Cerveza Polar Negra' -> 'POLAR NEGRA').
--   c) Validación estricta de stock disponible (evita stock negativo en concurrencia).
--   d) Registro atómico en public.kardex_movimientos dentro de la misma transacción.
--   e) Retorno enriquecido con 'numero_ticket' para la UI/Ticket de impresión.
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
SET search_path = public
AS $$
DECLARE
    v_comanda_id UUID;
    v_numero_ticket TEXT;
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

    -- Generar identificador legible de ticket
    v_numero_ticket := 'CMD-' || to_char(COALESCE(p_fecha, timezone('utc'::text, now())), 'YYYYMMDD') || '-' || UPPER(SUBSTRING(gen_random_uuid()::text FROM 1 FOR 6));

    -- 1. Insertar encabezado de comanda
    INSERT INTO public.comandas (
        fecha,
        nombre_cliente,
        sede_id,
        precio_total,
        notas,
        numero_ticket,
        cliente,
        total,
        subtotal
    ) VALUES (
        COALESCE(p_fecha, timezone('utc'::text, now())),
        TRIM(p_nombre_cliente),
        p_sede_id,
        0.00,
        p_notas,
        v_numero_ticket,
        TRIM(p_nombre_cliente),
        0.00,
        0.00
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

                    -- Bloquear y validar stock antes de descontar (evita stock negativo)
                    UPDATE public.insumos_inventario
                    SET stock_actual = stock_actual - v_descuento_cant,
                        updated_at = timezone('utc'::text, now())
                    WHERE id = v_insumo_id
                      AND stock_actual >= v_descuento_cant;

                    IF NOT FOUND THEN
                        RAISE EXCEPTION 'Stock insuficiente para el insumo "%" en la sede seleccionada', v_receta.insumo_nombre;
                    END IF;

                    -- Asentar en kardex atómicamente
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
                        'Comanda: ' || TRIM(p_nombre_cliente) || ' | Prep: ' || v_prod.nombre || ' | Ticket: ' || v_numero_ticket,
                        v_comanda_id
                    );
                END IF;
            END LOOP;
        ELSE
            -- Caso Directo por unidad (ej. Cerveza, Refresco, Botella directa)
            SELECT id INTO v_insumo_id 
            FROM public.insumos_inventario 
            WHERE sede_id = p_sede_id 
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

                -- Bloquear y validar stock antes de descontar (evita stock negativo)
                UPDATE public.insumos_inventario
                SET stock_actual = stock_actual - v_descuento_cant,
                    updated_at = timezone('utc'::text, now())
                WHERE id = v_insumo_id
                  AND stock_actual >= v_descuento_cant;

                IF NOT FOUND THEN
                    RAISE EXCEPTION 'Stock insuficiente para el producto "%" en la sede seleccionada', v_prod.nombre;
                END IF;

                -- Asentar en kardex atómicamente
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
                    'Comanda: ' || TRIM(p_nombre_cliente) || ' | Producto: ' || v_prod.nombre || ' | Ticket: ' || v_numero_ticket,
                    v_comanda_id
                );
            END IF;
        END IF;
    END LOOP;

    -- 3. Actualizar total final de la comanda en todas las columnas equivalentes
    UPDATE public.comandas
    SET precio_total = v_precio_total,
        total = v_precio_total,
        subtotal = v_precio_total
    WHERE id = v_comanda_id;

    RETURN jsonb_build_object(
        'success', true,
        'comanda_id', v_comanda_id,
        'numero_ticket', v_numero_ticket,
        'precio_total', v_precio_total,
        'nombre_cliente', TRIM(p_nombre_cliente)
    );
END;
$$;
