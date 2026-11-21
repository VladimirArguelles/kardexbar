-- ==============================================================================
-- MIGRACIÓN: ELIMINACIÓN DE INSUMOS OBSOLETOS NO INCLUIDOS EN CATÁLOGO OFICIAL
-- Archivo: supabase/migrations/20261121000001_cleanup_obsolete_insumos.sql
-- ==============================================================================

-- 1. Eliminar recetas vinculadas a productos inactivos
DELETE FROM public.recetas_escandallo 
WHERE producto_barra_id IN (
    SELECT id FROM public.productos_barra WHERE activo = false
);

-- 2. Eliminar recetas que apunten a insumos que van a ser eliminados
DELETE FROM public.recetas_escandallo 
WHERE insumo_id IN (
    SELECT id FROM public.insumos_inventario 
    WHERE nombre IN ('Ron Santa Teresa Gran Reserva', 'Refresco Coca Cola 2L', 'Limón Tahití')
);

-- 3. Asegurar que HIELO esté presente en Sede Secundaria
INSERT INTO public.insumos_inventario (sede_id, nombre, unidad_medida, stock_actual, stock_minimo, costo_unitario)
SELECT 
    s.id,
    'HIELO',
    'g',
    7000.00,
    1000.00,
    1.50
FROM public.sedes s
WHERE NOT EXISTS (
    SELECT 1 FROM public.insumos_inventario WHERE sede_id = s.id AND nombre = 'HIELO'
);

-- 4. Eliminar insumos obsoletos
DELETE FROM public.insumos_inventario 
WHERE nombre IN (
    'Agua Mineral 500ml',
    'Jugo de Naranja Natural',
    'Limón Tahití',
    'Refresco Coca Cola 2L',
    'Ron Santa Teresa Gran Reserva',
    'Vodka Absolut',
    'Whisky Black Label 12 Años',
    'Polar Pilsen',
    'Polar Light',
    'Bolsa de Hielo'
);
