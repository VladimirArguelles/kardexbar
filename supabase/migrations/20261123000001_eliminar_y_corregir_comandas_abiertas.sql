-- ==============================================================================
-- MIGRACIÓN: ELIMINAR COMANDAS ABIERTAS Y CORREGIR/CANCELAR PRODUCTOS POR ERROR
-- Archivo: supabase/migrations/20261123000001_eliminar_y_corregir_comandas_abiertas.sql
-- ==============================================================================

-- 1. RPC: eliminar_comanda_abierta
-- Elimina una comanda en estado ABIERTA y revierte el stock descontado en insumos_inventario
CREATE OR REPLACE FUNCTION public.eliminar_comanda_abierta(
    p_comanda_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_comanda RECORD;
    v_mov RECORD;
BEGIN
    SELECT * INTO v_comanda 
    FROM public.comandas 
    WHERE id = p_comanda_id AND estado = 'ABIERTA';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No se encontró la comanda abierta para eliminar o ya fue cerrada';
    END IF;

    -- 1. Revertir el stock en insumos_inventario según los movimientos de kardex registrados
    FOR v_mov IN 
        SELECT insumo_id, cantidad 
        FROM public.kardex_movimientos 
        WHERE referencia_id = p_comanda_id
    LOOP
        UPDATE public.insumos_inventario
        SET stock_actual = stock_actual + v_mov.cantidad,
            updated_at = timezone('utc'::text, now())
        WHERE id = v_mov.insumo_id;
    END LOOP;

    -- 2. Eliminar movimientos de kardex vinculados
    DELETE FROM public.kardex_movimientos WHERE referencia_id = p_comanda_id;

    -- 3. Eliminar detalles de la comanda
    DELETE FROM public.comanda_detalles WHERE comanda_id = p_comanda_id;

    -- 4. Eliminar la comanda
    DELETE FROM public.comandas WHERE id = p_comanda_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Comanda eliminada y stock revertido exitosamente'
    );
END;
$$;

-- 2. RPC: corregir_item_comanda_abierta
-- Permite corregir la cantidad o cancelar completamente un producto de una comanda abierta,
-- reponiendo el stock correspondiente al inventario.
CREATE OR REPLACE FUNCTION public.corregir_item_comanda_abierta(
    p_detalle_id UUID,
    p_nueva_cantidad NUMERIC,
    p_motivo TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_detalle RECORD;
    v_comanda RECORD;
    v_receta RECORD;
    v_insumo_id UUID;
    v_diff_cantidad NUMERIC(12, 2);
    v_reponer_cant NUMERIC(12, 2);
    v_nuevo_total NUMERIC(12, 2) := 0.00;
    v_items_restantes INT := 0;
BEGIN
    IF p_nueva_cantidad < 0 THEN
        RAISE EXCEPTION 'La cantidad no puede ser negativa';
    END IF;

    SELECT cd.*, pb.es_receta, pb.nombre AS prod_nombre 
    INTO v_detalle 
    FROM public.comanda_detalles cd
    JOIN public.productos_barra pb ON pb.id = cd.producto_barra_id
    WHERE cd.id = p_detalle_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Detalle de comanda no encontrado';
    END IF;

    SELECT * INTO v_comanda 
    FROM public.comandas 
    WHERE id = v_detalle.comanda_id AND estado = 'ABIERTA';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La comanda asociada no está abierta o no existe';
    END IF;

    v_diff_cantidad := v_detalle.cantidad - p_nueva_cantidad;

    -- Si se reduce la cantidad o se cancela el producto (v_diff_cantidad > 0), reponer el stock
    IF v_diff_cantidad > 0 THEN
        IF v_detalle.es_receta THEN
            FOR v_receta IN 
                SELECT re.insumo_id, re.cantidad_requerida, ii.nombre AS insumo_nombre
                FROM public.recetas_escandallo re
                JOIN public.insumos_inventario ii ON ii.id = re.insumo_id
                WHERE re.producto_barra_id = v_detalle.producto_barra_id
            LOOP
                SELECT id INTO v_insumo_id 
                FROM public.insumos_inventario 
                WHERE sede_id = v_comanda.sede_id 
                  AND (id = v_receta.insumo_id OR LOWER(TRIM(nombre)) = LOWER(TRIM(v_receta.insumo_nombre)))
                LIMIT 1;

                IF v_insumo_id IS NOT NULL THEN
                    v_reponer_cant := v_diff_cantidad * v_receta.cantidad_requerida;

                    UPDATE public.insumos_inventario
                    SET stock_actual = stock_actual + v_reponer_cant,
                        updated_at = timezone('utc'::text, now())
                    WHERE id = v_insumo_id;
                END IF;
            END LOOP;
        ELSE
            SELECT id INTO v_insumo_id 
            FROM public.insumos_inventario 
            WHERE sede_id = v_comanda.sede_id 
              AND (
                  LOWER(TRIM(nombre)) = LOWER(TRIM(v_detalle.prod_nombre))
                  OR LOWER(TRIM(nombre)) = LOWER(TRIM(REPLACE(REPLACE(v_detalle.prod_nombre, 'Cerveza ', ''), 'cerveza ', '')))
                  OR LOWER(TRIM(nombre)) = LOWER(TRIM(REPLACE(REPLACE(REPLACE(v_detalle.prod_nombre, 'Cerveza ', ''), 'cerveza ', ''), 'Ligth', 'Light')))
                  OR LOWER(TRIM(nombre)) = LOWER(TRIM(v_detalle.prod_nombre)) || ' (u)'
                  OR LOWER(TRIM(nombre)) = 'cerveza ' || LOWER(TRIM(REPLACE(REPLACE(v_detalle.prod_nombre, 'Cerveza ', ''), 'cerveza ', ''))) || ' (u)'
              )
            ORDER BY 
              (LOWER(TRIM(nombre)) = LOWER(TRIM(v_detalle.prod_nombre))) DESC,
              stock_actual DESC
            LIMIT 1;

            IF v_insumo_id IS NOT NULL THEN
                UPDATE public.insumos_inventario
                SET stock_actual = stock_actual + v_diff_cantidad,
                    updated_at = timezone('utc'::text, now())
                WHERE id = v_insumo_id;
            END IF;
        END IF;

        -- Registrar nota de corrección en la comanda
        IF p_motivo IS NOT NULL AND TRIM(p_motivo) <> '' THEN
            UPDATE public.comandas
            SET notas = CASE
                WHEN notas IS NOT NULL AND TRIM(notas) <> '' THEN
                    notas || E'\n[Corrección]: ' || TRIM(p_motivo)
                ELSE
                    '[Corrección]: ' || TRIM(p_motivo)
            END,
            updated_at = timezone('utc'::text, now())
            WHERE id = v_comanda.id;
        END IF;
    END IF;

    -- Actualizar o eliminar el detalle
    IF p_nueva_cantidad <= 0 THEN
        DELETE FROM public.comanda_detalles WHERE id = p_detalle_id;
    ELSE
        UPDATE public.comanda_detalles
        SET cantidad = p_nueva_cantidad
        WHERE id = p_detalle_id;
    END IF;

    -- Recalcular total de la comanda
    SELECT COALESCE(SUM(subtotal), 0) INTO v_nuevo_total
    FROM public.comanda_detalles
    WHERE comanda_id = v_comanda.id;

    SELECT COUNT(*) INTO v_items_restantes
    FROM public.comanda_detalles
    WHERE comanda_id = v_comanda.id;

    UPDATE public.comandas
    SET precio_total = v_nuevo_total,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_comanda.id;

    RETURN jsonb_build_object(
        'success', true,
        'nuevo_total', v_nuevo_total,
        'items_restantes', v_items_restantes,
        'comanda_id', v_comanda.id
    );
END;
$$;

-- 3. Permisos de ejecución
GRANT EXECUTE ON FUNCTION public.eliminar_comanda_abierta TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.corregir_item_comanda_abierta TO anon, authenticated, service_role;
