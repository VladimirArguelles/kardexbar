-- ==============================================================================
-- MIGRACIÓN RPC: CIERRE DIARIO Y ARQUEO AUTOMATIZADO DE BARRA
-- Archivo: supabase/migrations/20261117000001_rpc_cierre_diario.sql
-- ==============================================================================

-- 1. FUNCIÓN RPC: generar_cierre_diario
-- Calcula stock_inicial, surtido_dia y ventas_salidas_dia e inserta/actualiza en cierres_diarios
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
    -- Validar fecha
    IF p_fecha IS NULL THEN
        p_fecha := CURRENT_DATE;
    END IF;

    -- Asignar usuario responsable
    v_user := COALESCE(p_usuario_id, auth.uid());

    -- Recorrer todos los productos activos e inventariables
    FOR r_prod IN
        SELECT p.id, p.codigo, p.nombre, p.categoria, p.unidad_medida, p.stock_actual
        FROM public.productos p
        WHERE p.es_inventariable = true
          AND p.activo = true
        ORDER BY p.categoria, p.nombre
    LOOP
        -- A) CALCULAR STOCK INICIAL:
        -- 1. Intentar obtener el conteo físico (o stock teórico) del cierre del día anterior inmediato
        SELECT COALESCE(cd_ayer.conteo_fisico, cd_ayer.stock_teorico)
        INTO v_stock_inicial
        FROM public.cierres_diarios cd_ayer
        WHERE cd_ayer.fecha = (p_fecha - INTERVAL '1 day')::date
          AND cd_ayer.producto_id = r_prod.id;

        -- 2. Si no hubo cierre ayer, buscar el último cierre histórico anterior
        IF v_stock_inicial IS NULL THEN
            SELECT COALESCE(cd_ant.conteo_fisico, cd_ant.stock_teorico)
            INTO v_stock_inicial
            FROM public.cierres_diarios cd_ant
            WHERE cd_ant.fecha < p_fecha
              AND cd_ant.producto_id = r_prod.id
            ORDER BY cd_ant.fecha DESC
            LIMIT 1;
        END IF;

        -- 3. Si no existe ningún cierre previo registrado en el sistema, tomar el stock_actual
        IF v_stock_inicial IS NULL THEN
            v_stock_inicial := COALESCE(r_prod.stock_actual, 0.00);
        END IF;

        -- B) CALCULAR SURTIDO DEL DÍA:
        -- Entradas y traslados de bodega a barra en la fecha especificada
        SELECT COALESCE(SUM(mi_in.cantidad), 0.00)
        INTO v_surtido_dia
        FROM public.movimientos_inventario mi_in
        WHERE mi_in.producto_id = r_prod.id
          AND mi_in.fecha_movimiento::date = p_fecha
          AND mi_in.tipo_movimiento IN ('ENTRADA_SURTIDO', 'AJUSTE_POSITIVO')
          AND (mi_in.referencia_origen NOT LIKE 'ANULACIÓN%' OR mi_in.referencia_origen IS NULL);

        -- C) CALCULAR VENTAS Y SALIDAS DEL DÍA:
        -- 1. Salidas por comandas/tickets despachados en barra con estado CONFIRMADO
        SELECT COALESCE(SUM(dm.cantidad * re.factor_unidades_u), 0.00)
        INTO v_ventas_salidas_dia
        FROM public.detalle_movimientos dm
        JOIN public.movimientos m ON m.id = dm.movimiento_id
        JOIN public.recetas_equivalencias re ON re.presentacion_id = dm.presentacion_id
        WHERE re.producto_id = r_prod.id
          AND m.fecha_operacion::date = p_fecha
          AND m.estado = 'CONFIRMADO';

        -- 2. Sumar mermas, botellas rotas o desperdicios registrados en el día
        SELECT COALESCE(SUM(mi_out.cantidad), 0.00)
        INTO v_salidas_merma
        FROM public.movimientos_inventario mi_out
        WHERE mi_out.producto_id = r_prod.id
          AND mi_out.fecha_movimiento::date = p_fecha
          AND mi_out.tipo_movimiento IN ('SALIDA_DESPERDICIO', 'AJUSTE_NEGATIVO');

        v_ventas_salidas_dia := v_ventas_salidas_dia + v_salidas_merma;

        -- D) OBTENER CONTEO FÍSICO SI YA FUE PRECARGADO EN ESTE CIERRE
        SELECT cd_act.conteo_fisico
        INTO v_conteo_actual
        FROM public.cierres_diarios cd_act
        WHERE cd_act.fecha = p_fecha
          AND cd_act.producto_id = r_prod.id;

        -- E) INSERTAR O ACTUALIZAR CIERRE DIARIO
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
        WHERE cierres_diarios.cerrado = false; -- No sobreescribir días archivados/cerrados definitivamente

    END LOOP;

    -- RETORNAR EL LISTADO COMPLETO DEL ARQUEO PARA FLUTTER
    RETURN QUERY
    SELECT 
        cd.id AS cierre_id,
        cd.fecha,
        cd.producto_id,
        p.codigo AS codigo_producto,
        p.nombre AS nombre_producto,
        p.categoria,
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

-- 2. FUNCIÓN RPC AUXILIAR: registrar_conteo_fisico_y_cerrar
-- Permite que la app Flutter envíe en lote los conteos físicos del bartender y finalice el cierre
CREATE OR REPLACE FUNCTION public.registrar_conteo_fisico_y_cerrar(
    p_fecha DATE,
    p_conteos JSONB, -- Formato: [{"producto_id": "...", "conteo_fisico": 15.00}, ...]
    p_usuario_id UUID DEFAULT auth.uid(),
    p_observaciones TEXT DEFAULT NULL
)
RETURNS TABLE (
    cierre_id UUID,
    producto_id UUID,
    nombre_producto TEXT,
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
    elem JSONB;
    v_prod_id UUID;
    v_conteo NUMERIC(12, 2);
    v_user UUID;
BEGIN
    v_user := COALESCE(p_usuario_id, auth.uid());

    -- Asegurar que los cálculos base estén actualizados
    PERFORM public.generar_cierre_diario(p_fecha, v_user);

    -- Actualizar los conteos físicos proporcionados en el JSON
    FOR elem IN SELECT * FROM jsonb_array_elements(p_conteos)
    LOOP
        v_prod_id := (elem->>'producto_id')::UUID;
        v_conteo := (elem->>'conteo_fisico')::NUMERIC(12, 2);

        UPDATE public.cierres_diarios
        SET conteo_fisico = v_conteo,
            cerrado = true,
            usuario_id = v_user,
            observaciones = COALESCE(p_observaciones, observaciones),
            updated_at = timezone('utc'::text, now())
        WHERE fecha = p_fecha
          AND producto_id = v_prod_id;
    END LOOP;

    -- Si se enviaron observaciones generales, reflejarlas en todos los registros de la fecha
    IF p_observaciones IS NOT NULL THEN
        UPDATE public.cierres_diarios
        SET observaciones = p_observaciones,
            cerrado = true,
            updated_at = timezone('utc'::text, now())
        WHERE fecha = p_fecha;
    END IF;

    -- Retornar el resultado con las diferencias calculadas y auditadas
    RETURN QUERY
    SELECT 
        cd.id AS cierre_id,
        cd.producto_id,
        p.nombre AS nombre_producto,
        cd.stock_teorico,
        cd.conteo_fisico,
        cd.diferencia,
        cd.cerrado
    FROM public.cierres_diarios cd
    JOIN public.productos p ON p.id = cd.producto_id
    WHERE cd.fecha = p_fecha
    ORDER BY p.nombre;
END;
$$;
