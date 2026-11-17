-- ==============================================================================
-- MIGRACIÓN INICIAL: REGISTRO DE CONTROL DE VENTAS, BARRA E INVENTARIO
-- Archivo: supabase/migrations/20261117000000_init_control_ventas_inventario.sql
-- ==============================================================================

-- 1. EXTENSIONES
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. TIPOS ENUM PERSONALIZADOS
DO $$ BEGIN
    CREATE TYPE public.rol_usuario AS ENUM (
        'ADMINISTRADOR',
        'SUPERVISOR',
        'BARTENDER',
        'CAJERO'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE public.categoria_producto AS ENUM (
        'CERVEZA',
        'LICOR',
        'COCTEL',
        'BEBIDA_NO_ALCOHOLICA',
        'SERVICIO',
        'SNACK',
        'OTRO'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE public.canal_venta AS ENUM (
        'BARRA',
        'MESA',
        'RESERVACION',
        'EVENTO',
        'VIP'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE public.tipo_movimiento_inventario AS ENUM (
        'ENTRADA_SURTIDO',
        'SALIDA_VENTA',
        'SALIDA_DESPERDICIO',
        'AJUSTE_POSITIVO',
        'AJUSTE_NEGATIVO',
        'TRASLADO'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE public.estado_movimiento AS ENUM (
        'CONFIRMADO',
        'PENDIENTE',
        'ANULADO'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE public.tipo_operacion_venta AS ENUM (
        'VENTA',
        'CORTESIA',
        'CONSUMO_INTERNO',
        'PROMOCION'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE public.metodo_pago AS ENUM (
        'EFECTIVO_USD',
        'EFECTIVO_BS',
        'PAGO_MOVIL',
        'PUNTO_VENTA',
        'ZELLE',
        'MIXTO',
        'OTRO'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE public.tipo_diferencia_auditoria AS ENUM (
        'FALTANTE',
        'SOBRANTE',
        'EXACTO'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE public.estado_auditoria AS ENUM (
        'PENDIENTE_REVISION',
        'JUSTIFICADO',
        'APROBADO',
        'COBRADO_PERSONAL'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 3. FUNCIÓN DE ACTUALIZACIÓN DE TIMESTAMP (updated_at)
CREATE OR REPLACE FUNCTION public.actualizar_timestamp_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. TABLA: perfiles (Extensión de auth.users)
CREATE TABLE IF NOT EXISTS public.perfiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    apellido TEXT,
    correo TEXT,
    telefono TEXT,
    rol public.rol_usuario NOT NULL DEFAULT 'BARTENDER',
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TRIGGER trg_perfiles_updated_at
    BEFORE UPDATE ON public.perfiles
    FOR EACH ROW
    EXECUTE FUNCTION public.actualizar_timestamp_updated_at();

-- Función de ayuda de seguridad para consultar rol del usuario en sesión
CREATE OR REPLACE FUNCTION public.obtener_rol_actual()
RETURNS public.rol_usuario
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT rol FROM public.perfiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.es_admin_o_supervisor()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.perfiles
        WHERE id = auth.uid() AND rol IN ('ADMINISTRADOR', 'SUPERVISOR')
    );
$$;

-- 5. TABLA: productos (Insumos físicos e inventariables en barra/bodega)
CREATE TABLE IF NOT EXISTS public.productos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo TEXT UNIQUE NOT NULL,
    nombre TEXT UNIQUE NOT NULL,
    descripcion TEXT,
    categoria public.categoria_producto NOT NULL DEFAULT 'CERVEZA',
    unidad_medida TEXT NOT NULL DEFAULT 'UND',
    costo_unitario NUMERIC(12, 4) NOT NULL DEFAULT 0.0000 CHECK (costo_unitario >= 0),
    es_inventariable BOOLEAN NOT NULL DEFAULT true,
    stock_actual NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    stock_minimo NUMERIC(12, 2) NOT NULL DEFAULT 10.00 CHECK (stock_minimo >= 0),
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TRIGGER trg_productos_updated_at
    BEFORE UPDATE ON public.productos
    FOR EACH ROW
    EXECUTE FUNCTION public.actualizar_timestamp_updated_at();

-- 6. TABLA: presentaciones_venta (Catálogo comercial / Comandas / POS)
CREATE TABLE IF NOT EXISTS public.presentaciones_venta (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo TEXT UNIQUE NOT NULL,
    nombre TEXT UNIQUE NOT NULL,
    descripcion TEXT,
    categoria public.categoria_producto NOT NULL DEFAULT 'CERVEZA',
    canal_venta public.canal_venta NOT NULL DEFAULT 'BARRA',
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TRIGGER trg_presentaciones_venta_updated_at
    BEFORE UPDATE ON public.presentaciones_venta
    FOR EACH ROW
    EXECUTE FUNCTION public.actualizar_timestamp_updated_at();

-- 7. TABLA: recetas_equivalencias (Desconsolidación comercial a inventario físico)
CREATE TABLE IF NOT EXISTS public.recetas_equivalencias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    presentacion_id UUID NOT NULL REFERENCES public.presentaciones_venta(id) ON DELETE CASCADE,
    producto_id UUID NOT NULL REFERENCES public.productos(id) ON DELETE RESTRICT,
    factor_unidades_u NUMERIC(12, 4) NOT NULL CHECK (factor_unidades_u > 0),
    es_ingrediente_principal BOOLEAN NOT NULL DEFAULT true,
    notas TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_recetas_presentacion_producto UNIQUE (presentacion_id, producto_id)
);

-- 8. TABLA: historial_precios (Vigencia histórica de precios por presentación)
CREATE TABLE IF NOT EXISTS public.historial_precios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    presentacion_id UUID NOT NULL REFERENCES public.presentaciones_venta(id) ON DELETE CASCADE,
    precio_unitario NUMERIC(12, 2) NOT NULL CHECK (precio_unitario >= 0),
    fecha_desde TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    fecha_hasta TIMESTAMPTZ,
    activo BOOLEAN NOT NULL DEFAULT true,
    creado_por UUID REFERENCES public.perfiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Vista para consultar precios vigentes al momento
CREATE OR REPLACE VIEW public.vista_precios_vigentes AS
SELECT 
    pv.id AS presentacion_id,
    pv.codigo,
    pv.nombre,
    pv.categoria,
    pv.canal_venta,
    hp.id AS precio_id,
    hp.precio_unitario,
    hp.fecha_desde
FROM public.presentaciones_venta pv
JOIN public.historial_precios hp ON hp.presentacion_id = pv.id
WHERE pv.activo = true 
  AND hp.activo = true 
  AND (hp.fecha_hasta IS NULL OR hp.fecha_hasta > timezone('utc'::text, now()));

-- 9. TABLA: movimientos (Encabezado de Ventas / Despachos en Barra)
CREATE TABLE IF NOT EXISTS public.movimientos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    numero_ticket TEXT UNIQUE NOT NULL,
    fecha_operacion TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    tipo_operacion public.tipo_operacion_venta NOT NULL DEFAULT 'VENTA',
    canal public.canal_venta NOT NULL DEFAULT 'BARRA',
    estado public.estado_movimiento NOT NULL DEFAULT 'CONFIRMADO',
    metodo_pago public.metodo_pago NOT NULL DEFAULT 'EFECTIVO_USD',
    subtotal NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (subtotal >= 0),
    descuento NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (descuento >= 0),
    total NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (total >= 0),
    cliente_nombre TEXT,
    notas TEXT,
    usuario_id UUID REFERENCES public.perfiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TRIGGER trg_movimientos_updated_at
    BEFORE UPDATE ON public.movimientos
    FOR EACH ROW
    EXECUTE FUNCTION public.actualizar_timestamp_updated_at();

-- 10. TABLA: detalle_movimientos (Renglones de comanda/venta)
CREATE TABLE IF NOT EXISTS public.detalle_movimientos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    movimiento_id UUID NOT NULL REFERENCES public.movimientos(id) ON DELETE CASCADE,
    presentacion_id UUID NOT NULL REFERENCES public.presentaciones_venta(id) ON DELETE RESTRICT,
    cantidad NUMERIC(10, 2) NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12, 2) NOT NULL CHECK (precio_unitario >= 0),
    subtotal NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (subtotal >= 0),
    notas TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 11. TABLA: movimientos_inventario (Kardex detallado de inventario físico)
CREATE TABLE IF NOT EXISTS public.movimientos_inventario (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    producto_id UUID NOT NULL REFERENCES public.productos(id) ON DELETE RESTRICT,
    tipo_movimiento public.tipo_movimiento_inventario NOT NULL,
    cantidad NUMERIC(12, 2) NOT NULL CHECK (cantidad > 0),
    stock_anterior NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    stock_nuevo NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    referencia_origen TEXT,
    movimiento_id UUID REFERENCES public.movimientos(id) ON DELETE SET NULL,
    detalle_movimiento_id UUID REFERENCES public.detalle_movimientos(id) ON DELETE SET NULL,
    fecha_movimiento TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    motivo TEXT,
    usuario_id UUID REFERENCES public.perfiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 12. TABLA: cierres_diarios (Balance diario físico vs teórico por producto)
CREATE TABLE IF NOT EXISTS public.cierres_diarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fecha DATE NOT NULL,
    producto_id UUID NOT NULL REFERENCES public.productos(id) ON DELETE RESTRICT,
    stock_inicial NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    surtido_dia NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    ventas_salidas_dia NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    stock_teorico NUMERIC(12, 2) GENERATED ALWAYS AS (stock_inicial + surtido_dia - ventas_salidas_dia) STORED,
    conteo_fisico NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    diferencia NUMERIC(12, 2) GENERATED ALWAYS AS (conteo_fisico - (stock_inicial + surtido_dia - ventas_salidas_dia)) STORED,
    cerrado BOOLEAN NOT NULL DEFAULT false,
    usuario_id UUID REFERENCES public.perfiles(id) ON DELETE SET NULL,
    observaciones TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_cierre_fecha_producto UNIQUE (fecha, producto_id)
);

CREATE TRIGGER trg_cierres_diarios_updated_at
    BEFORE UPDATE ON public.cierres_diarios
    FOR EACH ROW
    EXECUTE FUNCTION public.actualizar_timestamp_updated_at();

-- 13. TABLA: auditoria_diferencias (Discrepancias detectadas en cierre)
CREATE TABLE IF NOT EXISTS public.auditoria_diferencias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cierre_id UUID NOT NULL REFERENCES public.cierres_diarios(id) ON DELETE CASCADE,
    producto_id UUID NOT NULL REFERENCES public.productos(id) ON DELETE RESTRICT,
    fecha DATE NOT NULL,
    diferencia NUMERIC(12, 2) NOT NULL,
    tipo_diferencia public.tipo_diferencia_auditoria NOT NULL,
    impacto_monetario_estimado NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    estado public.estado_auditoria NOT NULL DEFAULT 'PENDIENTE_REVISION',
    motivo_justificacion TEXT,
    revisado_por UUID REFERENCES public.perfiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_auditoria_cierre UNIQUE (cierre_id)
);

CREATE TRIGGER trg_auditoria_diferencias_updated_at
    BEFORE UPDATE ON public.auditoria_diferencias
    FOR EACH ROW
    EXECUTE FUNCTION public.actualizar_timestamp_updated_at();

-- ==============================================================================
-- 14. TRIGGERS DE NEGOCIO: CÁLCULOS, STOCK Y AUDITORÍA
-- ==============================================================================

-- A) Trigger para calcular subtotal en detalle_movimientos antes de insertar/actualizar
CREATE OR REPLACE FUNCTION public.fn_calcular_subtotal_detalle()
RETURNS TRIGGER AS $$
BEGIN
    NEW.subtotal := ROUND(NEW.cantidad * NEW.precio_unitario, 2);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calcular_subtotal_detalle
    BEFORE INSERT OR UPDATE ON public.detalle_movimientos
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_calcular_subtotal_detalle();

-- B) Trigger para sincronizar totales en cabecera de movimiento
CREATE OR REPLACE FUNCTION public.fn_sincronizar_totales_movimiento()
RETURNS TRIGGER AS $$
DECLARE
    v_movimiento_id UUID;
    v_nuevo_subtotal NUMERIC(12, 2);
    v_descuento NUMERIC(12, 2);
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_movimiento_id := OLD.movimiento_id;
    ELSE
        v_movimiento_id := NEW.movimiento_id;
    END IF;

    SELECT COALESCE(SUM(subtotal), 0.00)
    INTO v_nuevo_subtotal
    FROM public.detalle_movimientos
    WHERE movimiento_id = v_movimiento_id;

    SELECT COALESCE(descuento, 0.00)
    INTO v_descuento
    FROM public.movimientos
    WHERE id = v_movimiento_id;

    UPDATE public.movimientos
    SET subtotal = v_nuevo_subtotal,
        total = GREATEST(v_nuevo_subtotal - v_descuento, 0.00),
        updated_at = timezone('utc'::text, now())
    WHERE id = v_movimiento_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sincronizar_totales_movimiento
    AFTER INSERT OR UPDATE OR DELETE ON public.detalle_movimientos
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_sincronizar_totales_movimiento();

-- C) Trigger de descuento automático de inventario físico por comanda/venta
CREATE OR REPLACE FUNCTION public.fn_procesar_descuento_inventario_detalle()
RETURNS TRIGGER AS $$
DECLARE
    rec_receta RECORD;
    v_mov_estado public.estado_movimiento;
    v_ticket TEXT;
    v_usuario UUID;
    v_unidades_descontar NUMERIC(12, 2);
    v_stock_previo NUMERIC(12, 2);
    v_stock_nuevo NUMERIC(12, 2);
BEGIN
    -- Obtener estado, ticket y usuario del movimiento padre
    SELECT estado, numero_ticket, usuario_id
    INTO v_mov_estado, v_ticket, v_usuario
    FROM public.movimientos
    WHERE id = NEW.movimiento_id;

    -- Solo procesar salidas de inventario si el movimiento está CONFIRMADO
    IF v_mov_estado = 'CONFIRMADO' THEN
        FOR rec_receta IN
            SELECT r.producto_id, r.factor_unidades_u, p.es_inventariable, p.stock_actual
            FROM public.recetas_equivalencias r
            JOIN public.productos p ON p.id = r.producto_id
            WHERE r.presentacion_id = NEW.presentacion_id
        LOOP
            IF rec_receta.es_inventariable = true THEN
                v_unidades_descontar := ROUND(NEW.cantidad * rec_receta.factor_unidades_u, 2);
                v_stock_previo := rec_receta.stock_actual;
                v_stock_nuevo := v_stock_previo - v_unidades_descontar;

                -- Actualizar stock físico en tabla productos
                UPDATE public.productos
                SET stock_actual = v_stock_nuevo,
                    updated_at = timezone('utc'::text, now())
                WHERE id = rec_receta.producto_id;

                -- Registrar traza en movimientos_inventario
                INSERT INTO public.movimientos_inventario (
                    producto_id,
                    tipo_movimiento,
                    cantidad,
                    stock_anterior,
                    stock_nuevo,
                    referencia_origen,
                    movimiento_id,
                    detalle_movimiento_id,
                    motivo,
                    usuario_id
                ) VALUES (
                    rec_receta.producto_id,
                    'SALIDA_VENTA',
                    v_unidades_descontar,
                    v_stock_previo,
                    v_stock_nuevo,
                    'TICKET: ' || COALESCE(v_ticket, 'S/N'),
                    NEW.movimiento_id,
                    NEW.id,
                    'Despacho por venta de comanda',
                    v_usuario
                );
            END IF;
        END LOOP;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_procesar_descuento_inventario_detalle
    AFTER INSERT ON public.detalle_movimientos
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_procesar_descuento_inventario_detalle();

-- D) Trigger para revertir inventario en caso de anulación de comanda/movimiento
CREATE OR REPLACE FUNCTION public.fn_revertir_inventario_anulacion()
RETURNS TRIGGER AS $$
DECLARE
    rec_kardex RECORD;
BEGIN
    IF OLD.estado = 'CONFIRMADO' AND NEW.estado = 'ANULADO' THEN
        FOR rec_kardex IN
            SELECT mi.producto_id, mi.cantidad, p.stock_actual
            FROM public.movimientos_inventario mi
            JOIN public.productos p ON p.id = mi.producto_id
            WHERE mi.movimiento_id = NEW.id
              AND mi.tipo_movimiento = 'SALIDA_VENTA'
        LOOP
            -- Reponer el stock en la tabla productos
            UPDATE public.productos
            SET stock_actual = stock_actual + rec_kardex.cantidad,
                updated_at = timezone('utc'::text, now())
            WHERE id = rec_kardex.producto_id;

            -- Registrar ajuste compensatorio en movimientos_inventario
            INSERT INTO public.movimientos_inventario (
                producto_id,
                tipo_movimiento,
                cantidad,
                stock_anterior,
                stock_nuevo,
                referencia_origen,
                movimiento_id,
                motivo,
                usuario_id
            ) VALUES (
                rec_kardex.producto_id,
                'AJUSTE_POSITIVO',
                rec_kardex.cantidad,
                rec_kardex.stock_actual,
                rec_kardex.stock_actual + rec_kardex.cantidad,
                'ANULACIÓN TICKET: ' || NEW.numero_ticket,
                NEW.id,
                'Reposición de stock por anulación de comanda',
                NEW.usuario_id
            );
        END LOOP;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_revertir_inventario_anulacion
    AFTER UPDATE OF estado ON public.movimientos
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_revertir_inventario_anulacion();

-- E) Trigger en movimientos_inventario para surtidos manuales / traslados directos
CREATE OR REPLACE FUNCTION public.fn_actualizar_stock_por_movimiento_manual()
RETURNS TRIGGER AS $$
DECLARE
    v_stock_actual NUMERIC(12, 2);
    v_stock_nuevo NUMERIC(12, 2);
BEGIN
    -- Solo aplicar si no proviene de venta automática (para evitar dobles aplicaciones)
    IF NEW.tipo_movimiento IN ('ENTRADA_SURTIDO', 'AJUSTE_POSITIVO') AND NEW.detalle_movimiento_id IS NULL THEN
        SELECT stock_actual INTO v_stock_actual FROM public.productos WHERE id = NEW.producto_id FOR UPDATE;
        v_stock_nuevo := v_stock_actual + NEW.cantidad;
        
        NEW.stock_anterior := v_stock_actual;
        NEW.stock_nuevo := v_stock_nuevo;
        
        UPDATE public.productos
        SET stock_actual = v_stock_nuevo,
            updated_at = timezone('utc'::text, now())
        WHERE id = NEW.producto_id;

    ELSIF NEW.tipo_movimiento IN ('SALIDA_DESPERDICIO', 'AJUSTE_NEGATIVO') AND NEW.detalle_movimiento_id IS NULL THEN
        SELECT stock_actual INTO v_stock_actual FROM public.productos WHERE id = NEW.producto_id FOR UPDATE;
        v_stock_nuevo := v_stock_actual - NEW.cantidad;
        
        NEW.stock_anterior := v_stock_actual;
        NEW.stock_nuevo := v_stock_nuevo;
        
        UPDATE public.productos
        SET stock_actual = v_stock_nuevo,
            updated_at = timezone('utc'::text, now())
        WHERE id = NEW.producto_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_actualizar_stock_por_movimiento_manual
    BEFORE INSERT ON public.movimientos_inventario
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_actualizar_stock_por_movimiento_manual();

-- F) Trigger para registrar automáticamente auditoría de diferencias en cierre diario
CREATE OR REPLACE FUNCTION public.fn_auditar_diferencias_cierre()
RETURNS TRIGGER AS $$
DECLARE
    v_costo_unitario NUMERIC(12, 4);
    v_impacto NUMERIC(12, 2);
    v_tipo_dif public.tipo_diferencia_auditoria;
BEGIN
    IF NEW.diferencia <> 0.00 THEN
        IF NEW.diferencia < 0 THEN
            v_tipo_dif := 'FALTANTE';
        ELSE
            v_tipo_dif := 'SOBRANTE';
        END IF;

        -- Obtener costo unitario del producto para estimar impacto económico
        SELECT COALESCE(costo_unitario, 0.0000)
        INTO v_costo_unitario
        FROM public.productos
        WHERE id = NEW.producto_id;

        v_impacto := ROUND(ABS(NEW.diferencia) * v_costo_unitario, 2);

        INSERT INTO public.auditoria_diferencias (
            cierre_id,
            producto_id,
            fecha,
            diferencia,
            tipo_diferencia,
            impacto_monetario_estimado,
            estado,
            motivo_justificacion
        ) VALUES (
            NEW.id,
            NEW.producto_id,
            NEW.fecha,
            NEW.diferencia,
            v_tipo_dif,
            v_impacto,
            'PENDIENTE_REVISION',
            COALESCE(NEW.observaciones, 'Diferencia detectada en arqueo diario')
        )
        ON CONFLICT (cierre_id) DO UPDATE SET
            diferencia = EXCLUDED.diferencia,
            tipo_diferencia = EXCLUDED.tipo_diferencia,
            impacto_monetario_estimado = EXCLUDED.impacto_monetario_estimado,
            updated_at = timezone('utc'::text, now());
    ELSE
        -- Si la diferencia es 0 y existía una auditoría previa, se actualiza a EXACTO
        UPDATE public.auditoria_diferencias
        SET diferencia = 0.00,
            tipo_diferencia = 'EXACTO',
            impacto_monetario_estimado = 0.00,
            estado = 'APROBADO',
            motivo_justificacion = 'Conteo físico exacto verificado',
            updated_at = timezone('utc'::text, now())
        WHERE cierre_id = NEW.id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auditar_diferencias_cierre
    AFTER INSERT OR UPDATE OF conteo_fisico, cerrado ON public.cierres_diarios
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_auditar_diferencias_cierre();

-- ==============================================================================
-- 15. ÍNDICES DE RENDIMIENTO PARA FLUTTER Y CONSULTAS ANALÍTICAS
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_productos_categoria ON public.productos(categoria);
CREATE INDEX IF NOT EXISTS idx_productos_es_inventariable ON public.productos(es_inventariable);
CREATE INDEX IF NOT EXISTS idx_presentaciones_canal ON public.presentaciones_venta(canal_venta);
CREATE INDEX IF NOT EXISTS idx_recetas_presentacion ON public.recetas_equivalencias(presentacion_id);
CREATE INDEX IF NOT EXISTS idx_recetas_producto ON public.recetas_equivalencias(producto_id);
CREATE INDEX IF NOT EXISTS idx_historial_precios_activos ON public.historial_precios(presentacion_id, activo, fecha_hasta);
CREATE INDEX IF NOT EXISTS idx_movimientos_fecha ON public.movimientos(fecha_operacion);
CREATE INDEX IF NOT EXISTS idx_movimientos_estado ON public.movimientos(estado);
CREATE INDEX IF NOT EXISTS idx_movimientos_usuario ON public.movimientos(usuario_id);
CREATE INDEX IF NOT EXISTS idx_detalle_movimientos_movimiento ON public.detalle_movimientos(movimiento_id);
CREATE INDEX IF NOT EXISTS idx_detalle_movimientos_presentacion ON public.detalle_movimientos(presentacion_id);
CREATE INDEX IF NOT EXISTS idx_kardex_producto_fecha ON public.movimientos_inventario(producto_id, fecha_movimiento);
CREATE INDEX IF NOT EXISTS idx_cierres_diarios_fecha ON public.cierres_diarios(fecha);
CREATE INDEX IF NOT EXISTS idx_cierres_diarios_producto ON public.cierres_diarios(producto_id);
CREATE INDEX IF NOT EXISTS idx_auditoria_fecha ON public.auditoria_diferencias(fecha);

-- ==============================================================================
-- 16. SEGURIDAD: ROW LEVEL SECURITY (RLS) Y POLÍTICAS
-- ==============================================================================

ALTER TABLE public.perfiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.productos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.presentaciones_venta ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recetas_equivalencias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.historial_precios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.movimientos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.detalle_movimientos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.movimientos_inventario ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cierres_diarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auditoria_diferencias ENABLE ROW LEVEL SECURITY;

-- Políticas: perfiles
CREATE POLICY "perfiles_select_autenticados" ON public.perfiles
    FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "perfiles_update_propio_o_admin" ON public.perfiles
    FOR UPDATE TO authenticated
    USING (auth.uid() = id OR public.es_admin_o_supervisor())
    WITH CHECK (auth.uid() = id OR public.es_admin_o_supervisor());

CREATE POLICY "perfiles_insert_admin" ON public.perfiles
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = id OR public.es_admin_o_supervisor());

-- Políticas: productos
CREATE POLICY "productos_select_todos" ON public.productos
    FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "productos_insert_admin" ON public.productos
    FOR INSERT TO authenticated
    WITH CHECK (public.es_admin_o_supervisor());

CREATE POLICY "productos_update_admin" ON public.productos
    FOR UPDATE TO authenticated
    USING (public.es_admin_o_supervisor());

CREATE POLICY "productos_delete_admin" ON public.productos
    FOR DELETE TO authenticated
    USING (public.es_admin_o_supervisor());

-- Políticas: presentaciones_venta
CREATE POLICY "presentaciones_select_todos" ON public.presentaciones_venta
    FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "presentaciones_all_admin" ON public.presentaciones_venta
    FOR ALL TO authenticated
    USING (public.es_admin_o_supervisor())
    WITH CHECK (public.es_admin_o_supervisor());

-- Políticas: recetas_equivalencias
CREATE POLICY "recetas_select_todos" ON public.recetas_equivalencias
    FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "recetas_all_admin" ON public.recetas_equivalencias
    FOR ALL TO authenticated
    USING (public.es_admin_o_supervisor())
    WITH CHECK (public.es_admin_o_supervisor());

-- Políticas: historial_precios
CREATE POLICY "precios_select_todos" ON public.historial_precios
    FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "precios_all_admin" ON public.historial_precios
    FOR ALL TO authenticated
    USING (public.es_admin_o_supervisor())
    WITH CHECK (public.es_admin_o_supervisor());

-- Políticas: movimientos (Ventas/Comandas)
CREATE POLICY "movimientos_select_autenticados" ON public.movimientos
    FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "movimientos_insert_autenticados" ON public.movimientos
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "movimientos_update_autenticados" ON public.movimientos
    FOR UPDATE TO authenticated
    USING (usuario_id = auth.uid() OR public.es_admin_o_supervisor());

-- Políticas: detalle_movimientos
CREATE POLICY "detalle_movimientos_select_autenticados" ON public.detalle_movimientos
    FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "detalle_movimientos_insert_autenticados" ON public.detalle_movimientos
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "detalle_movimientos_update_admin" ON public.detalle_movimientos
    FOR UPDATE TO authenticated
    USING (public.es_admin_o_supervisor());

CREATE POLICY "detalle_movimientos_delete_admin" ON public.detalle_movimientos
    FOR DELETE TO authenticated
    USING (public.es_admin_o_supervisor());

-- Políticas: movimientos_inventario (Kardex)
CREATE POLICY "kardex_select_autenticados" ON public.movimientos_inventario
    FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "kardex_insert_autenticados" ON public.movimientos_inventario
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "kardex_update_admin" ON public.movimientos_inventario
    FOR UPDATE TO authenticated
    USING (public.es_admin_o_supervisor());

-- Políticas: cierres_diarios
CREATE POLICY "cierres_select_autenticados" ON public.cierres_diarios
    FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "cierres_insert_autenticados" ON public.cierres_diarios
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "cierres_update_autenticados" ON public.cierres_diarios
    FOR UPDATE TO authenticated
    USING (auth.uid() IS NOT NULL);

-- Políticas: auditoria_diferencias
CREATE POLICY "auditoria_select_autenticados" ON public.auditoria_diferencias
    FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "auditoria_all_supervisor_admin" ON public.auditoria_diferencias
    FOR ALL TO authenticated
    USING (public.es_admin_o_supervisor())
    WITH CHECK (public.es_admin_o_supervisor());
