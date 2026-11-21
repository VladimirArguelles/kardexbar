-- ==============================================================================
-- MIGRACIÓN: SINCRONIZACIÓN EXCLUSIVA DE PRODUCTOS, SERVICIOS E INSUMOS
-- Archivo: supabase/migrations/20261120000001_sync_word_productos_servicios_kardex.sql
-- ==============================================================================

-- 1. CORRECCIÓN DE COLUMNAS EN TABLA COMANDAS
ALTER TABLE public.comandas 
    ADD COLUMN IF NOT EXISTS nombre_cliente TEXT,
    ADD COLUMN IF NOT EXISTS sede_id UUID REFERENCES public.sedes(id),
    ADD COLUMN IF NOT EXISTS precio_total NUMERIC(12, 2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS notas TEXT;

UPDATE public.comandas 
SET nombre_cliente = COALESCE(nombre_cliente, cliente, 'Cliente Barra'),
    precio_total = COALESCE(precio_total, total, 0.00)
WHERE nombre_cliente IS NULL OR precio_total IS NULL;

UPDATE public.comandas 
SET sede_id = (SELECT id FROM public.sedes WHERE es_principal = true LIMIT 1)
WHERE sede_id IS NULL;

-- 2. AMPLIAR RESTRICCIONES DE CATEGORÍAS Y UNIDADES DE MEDIDA
ALTER TABLE public.productos_barra DROP CONSTRAINT IF EXISTS productos_barra_categoria_check;
ALTER TABLE public.productos_barra ADD CONSTRAINT productos_barra_categoria_check 
CHECK (categoria IN ('Cocteles', 'Sin Alcohol & Jugos', 'Licores & Destilados', 'Cervezas', 'Ofertas & Servicios', 'Jugos', 'Licores', 'No Alcoholicas'));

ALTER TABLE public.insumos_inventario DROP CONSTRAINT IF EXISTS insumos_inventario_unidad_medida_check;
ALTER TABLE public.insumos_inventario ADD CONSTRAINT insumos_inventario_unidad_medida_check 
CHECK (unidad_medida IN ('unidad', 'caja', 'ml', 'gr', 'bolsa_hielo', 'manojo', 'bandeja', 'paquete', 'lt', 'mlt', 'g', 'Unidad', 'Bandeja', 'Manojo', 'Paquete'));

-- 3. DESACTIVAR PRODUCTOS QUE NO PERTENECEN AL DOCUMENTO WORD EXCLUSIVO
UPDATE public.productos_barra SET activo = false WHERE nombre NOT IN (
    'Grinch', 'Cuba Libre', 'Mojito Cubano', 'Laguna Azul', 'Buscando a Nemo',
    'Michelada', 'Sangría', 'Buena Vibra', 'Cosmopolitan', 'Pantera Rosa',
    'Tequila Sunrise', 'Tinto de Verano', 'Margarita Blue', 'Daiquiri Fresa', 'Piña Colada',
    'Jugo de Fresa', 'Jugo de Piña', 'Jugo de Parchita', 'Limonada',
    'Malteada Oreo', 'Malteada Samba', 'Malteada Flips',
    'Whisky 12 Años', 'Whisky 8 Años', 'Vino', 'Shot Tequila (José Cuervo)', 'Sangría 1.75mlt',
    'Cerveza Zulia/Polar', 'Cerveza Polar Negra', 'Cerveza Polar Ligth', 'Cerveza Zulia',
    'Cerveza Solera Azul', 'Cerveza Solera Verde', 'Cerveza Zulia Lata',
    'Balde Zulia/Polar (10 Uds.)', 'Balde Solera (10 Uds.)', '½ Caja Cerveza Zulia/Polar', 'Caja de Cerveza Zulia/Polar',
    'Coctel Reservación / Cumpleaños', 'Coctel Combo', 'Balde Reservación (10 Uds.)',
    'Servicio Cumpleaños', 'Servicio Reservaciones', 'Servicio Combos'
);

-- 4. INSERTAR/ACTUALIZAR CATÁLOGO OFICIAL DE PRODUCTOS DE BARRA
INSERT INTO public.productos_barra (nombre, categoria, precio_venta, es_receta, activo) VALUES
    ('Grinch', 'Cocteles', 4.00, true, true),
    ('Cuba Libre', 'Cocteles', 4.00, true, true),
    ('Mojito Cubano', 'Cocteles', 4.00, true, true),
    ('Laguna Azul', 'Cocteles', 4.00, true, true),
    ('Buscando a Nemo', 'Cocteles', 4.00, true, true),
    ('Michelada', 'Cocteles', 4.00, true, true),
    ('Sangría', 'Cocteles', 4.00, true, true),
    ('Buena Vibra', 'Cocteles', 4.50, true, true),
    ('Cosmopolitan', 'Cocteles', 4.50, true, true),
    ('Pantera Rosa', 'Cocteles', 4.50, true, true),
    ('Tequila Sunrise', 'Cocteles', 4.50, true, true),
    ('Tinto de Verano', 'Cocteles', 4.50, true, true),
    ('Margarita Blue', 'Cocteles', 4.50, true, true),
    ('Daiquiri Fresa', 'Cocteles', 5.00, true, true),
    ('Piña Colada', 'Cocteles', 5.00, true, true),
    ('Jugo de Fresa', 'Sin Alcohol & Jugos', 3.00, false, true),
    ('Jugo de Piña', 'Sin Alcohol & Jugos', 3.00, false, true),
    ('Jugo de Parchita', 'Sin Alcohol & Jugos', 3.00, false, true),
    ('Limonada', 'Sin Alcohol & Jugos', 3.00, false, true),
    ('Malteada Oreo', 'Sin Alcohol & Jugos', 6.50, false, true),
    ('Malteada Samba', 'Sin Alcohol & Jugos', 6.50, false, true),
    ('Malteada Flips', 'Sin Alcohol & Jugos', 6.50, false, true),
    ('Whisky 12 Años', 'Licores & Destilados', 5.50, false, true),
    ('Whisky 8 Años', 'Licores & Destilados', 4.00, false, true),
    ('Vino', 'Licores & Destilados', 4.50, false, true),
    ('Shot Tequila (José Cuervo)', 'Licores & Destilados', 4.50, false, true),
    ('Sangría 1.75mlt', 'Licores & Destilados', 9.00, false, true),
    ('Cerveza Zulia/Polar', 'Cervezas', 1.20, false, true),
    ('Cerveza Polar Negra', 'Cervezas', 1.20, false, true),
    ('Cerveza Polar Ligth', 'Cervezas', 1.20, false, true),
    ('Cerveza Zulia', 'Cervezas', 1.20, false, true),
    ('Cerveza Solera Azul', 'Cervezas', 1.40, false, true),
    ('Cerveza Solera Verde', 'Cervezas', 1.40, false, true),
    ('Cerveza Zulia Lata', 'Cervezas', 2.00, false, true),
    ('Balde Zulia/Polar (10 Uds.)', 'Cervezas', 10.00, false, true),
    ('Balde Solera (10 Uds.)', 'Cervezas', 12.00, false, true),
    ('½ Caja Cerveza Zulia/Polar', 'Cervezas', 15.00, false, true),
    ('Caja de Cerveza Zulia/Polar', 'Cervezas', 30.00, false, true),
    ('Coctel Reservación / Cumpleaños', 'Ofertas & Servicios', 2.00, true, true),
    ('Coctel Combo', 'Ofertas & Servicios', 2.50, true, true),
    ('Balde Reservación (10 Uds.)', 'Ofertas & Servicios', 9.00, false, true),
    ('Servicio Cumpleaños', 'Ofertas & Servicios', 0.00, false, true),
    ('Servicio Reservaciones', 'Ofertas & Servicios', 0.00, false, true),
    ('Servicio Combos', 'Ofertas & Servicios', 0.00, false, true)
ON CONFLICT (nombre) DO UPDATE SET
    categoria = EXCLUDED.categoria,
    precio_venta = EXCLUDED.precio_venta,
    es_receta = EXCLUDED.es_receta,
    activo = true;

-- 5. POBLAR INSUMOS OFICIALES PARA SEDE PRINCIPAL
DO $$
DECLARE
    v_prin UUID;
BEGIN
    SELECT id INTO v_prin FROM public.sedes WHERE es_principal = true LIMIT 1;

    INSERT INTO public.insumos_inventario (sede_id, nombre, unidad_medida, stock_actual, stock_minimo, costo_unitario) VALUES
        (v_prin, 'RON 5 ESTRELLA BLANCO 0,70Lt', 'ml', 700.00, 5.00, 1.00),
        (v_prin, 'RON 5 ESTRELLA BLANCO 1Lt', 'ml', 1000.00, 5.00, 1.00),
        (v_prin, 'RON 5 ESTRELLA DORADO', 'ml', 1000.00, 5.00, 1.00),
        (v_prin, 'CACIQUE', 'ml', 750.00, 5.00, 1.00),
        (v_prin, 'PAMPERO', 'ml', 700.00, 5.00, 1.00),
        (v_prin, 'VODKA XTREME', 'ml', 700.00, 5.00, 1.00),
        (v_prin, 'VODKA BAJO 0', 'ml', 700.00, 5.00, 1.00),
        (v_prin, 'WHISKY B&W', 'ml', 750.00, 5.00, 1.00),
        (v_prin, 'WHISKI BUCHANAN´S', 'ml', 700.00, 5.00, 1.00),
        (v_prin, 'TEQUILA CHIAPAS', 'ml', 700.00, 5.00, 1.00),
        (v_prin, 'TEQUILA JOSE CUERVOS', 'ml', 700.00, 5.00, 1.00),
        (v_prin, 'VINO 3 MEDALLAS', 'ml', 700.00, 5.00, 1.00),
        (v_prin, 'VINO GATO NEGRO', 'ml', 700.00, 5.00, 1.00),
        (v_prin, 'CAROREÑA', 'ml', 1750.00, 5.00, 1.00),
        (v_prin, 'LICOR DE COCO', 'ml', 700.00, 5.00, 1.00),
        (v_prin, 'TRIPLE SEC', 'ml', 700.00, 5.00, 1.00),
        (v_prin, 'CURAZAO AZUL', 'ml', 700.00, 5.00, 1.00),
        (v_prin, 'GRANADINA', 'ml', 700.00, 5.00, 1.00),
        (v_prin, 'AMARGO DE ANGOSTURA', 'ml', 140.00, 5.00, 1.00),
        (v_prin, 'TAJIN', 'gr', 142.00, 5.00, 1.00),
        (v_prin, 'PICANTE', 'gr', 150.00, 5.00, 1.00),
        (v_prin, 'LECHE LIQUIDA', 'ml', 1000.00, 5.00, 1.00),
        (v_prin, 'LECHE CONDESADA 14oz', 'gr', 395.00, 5.00, 1.00),
        (v_prin, 'LECHE EVAPORADA', 'gr', 410.00, 5.00, 1.00),
        (v_prin, 'JUGO DE NARANJA', 'ml', 1500.00, 5.00, 1.00),
        (v_prin, 'COCA COLA 1.5l', 'ml', 1500.00, 5.00, 1.00),
        (v_prin, 'COCA COLA 1l', 'ml', 1000.00, 5.00, 1.00),
        (v_prin, 'COCA COLA 355mlt', 'ml', 355.00, 5.00, 1.00),
        (v_prin, 'REFRESCO LIMON 1.5lt', 'ml', 1500.00, 5.00, 1.00),
        (v_prin, 'REFRESCO LIMON 1lt', 'ml', 1000.00, 5.00, 1.00),
        (v_prin, 'REFRESCO LIMON 355mlt', 'ml', 355.00, 5.00, 1.00),
        (v_prin, 'TELISTO LIMON', 'gr', 400.00, 5.00, 1.00),
        (v_prin, 'TELISTO DURAZNO', 'gr', 400.00, 5.00, 1.00),
        (v_prin, 'CORONA CERVEZA', 'unidad', 24.00, 5.00, 1.00),
        (v_prin, 'CEREZA', 'gr', 100.00, 5.00, 1.00),
        (v_prin, 'HIERBA BUENA', 'manojo', 1.00, 5.00, 1.00),
        (v_prin, 'PIÑA', 'unidad', 1.00, 5.00, 1.00),
        (v_prin, 'FRESA', 'bandeja', 1.00, 5.00, 1.00),
        (v_prin, 'LIMON', 'gr', 1000.00, 5.00, 1.00),
        (v_prin, 'PARCHITA', 'gr', 1000.00, 5.00, 1.00),
        (v_prin, 'AZUCAR', 'gr', 1000.00, 5.00, 1.00),
        (v_prin, 'PITILLO', 'paquete', 100.00, 5.00, 1.00),
        (v_prin, 'HIELO', 'gr', 7000.00, 5.00, 1.00),
        (v_prin, 'Bolsa de Hielo', 'bolsa_hielo', 25.00, 5.00, 1.50),
        (v_prin, 'HELADO', 'lt', 4.70, 5.00, 1.00),
        (v_prin, 'TRULULU', 'gr', 600.00, 5.00, 1.00),
        (v_prin, 'OREO', 'gr', 432.00, 5.00, 1.00),
        (v_prin, 'FLIPS', 'gr', 120.00, 5.00, 1.00),
        (v_prin, 'SAMBA', 'gr', 32.00, 5.00, 1.00),
        (v_prin, 'POLAR NEGRA', 'unidad', 36.00, 5.00, 1.00),
        (v_prin, 'POLAR LIGHT', 'unidad', 36.00, 5.00, 1.00),
        (v_prin, 'ZULIA', 'unidad', 36.00, 5.00, 1.00),
        (v_prin, 'SOLERA AZUL', 'unidad', 36.00, 5.00, 1.00),
        (v_prin, 'SOLERA VERDE', 'unidad', 36.00, 5.00, 1.00),
        (v_prin, 'ZULIA LATA', 'unidad', 24.00, 5.00, 1.00),
        (v_prin, 'CAROREÑA LATA', 'unidad', 24.00, 5.00, 1.00),
        (v_prin, 'MOJITO LATA', 'unidad', 24.00, 5.00, 1.00),
        (v_prin, 'VASO CON TAPA', 'unidad', 100.00, 5.00, 1.00),
        (v_prin, 'REFRESCO LIMON 2lt', 'ml', 2000.00, 5.00, 1.00),
        (v_prin, 'LECHE CONDENSADA 12oz', 'gr', 340.00, 5.00, 1.00),
        (v_prin, 'TELISTO LIMON 240', 'gr', 240.00, 5.00, 1.00),
        (v_prin, 'TELISTO DURAZNO 450', 'gr', 450.00, 5.00, 1.00),
        (v_prin, 'SIROPE CHOCOLATE', 'gr', 200.00, 5.00, 1.00),
        (v_prin, 'SIROPE CHOCOLATE 1kg', 'gr', 1000.00, 5.00, 1.00),
        (v_prin, 'CEREZA 125g', 'gr', 125.00, 5.00, 1.00),
        (v_prin, 'CEREZA 190g', 'gr', 190.00, 5.00, 1.00),
        (v_prin, 'CERVEZA ZULIA (U)', 'unidad', 1.00, 5.00, 1.00),
        (v_prin, 'CERVEZA POLAR NEGRA (U)', 'unidad', 1.00, 5.00, 1.00),
        (v_prin, 'CERVEZA POLAR LIGHT (U)', 'unidad', 1.00, 5.00, 1.00),
        (v_prin, 'CERVEZA SOLERA (U)', 'unidad', 1.00, 5.00, 1.00),
        (v_prin, 'ZULIA LATA (U)', 'unidad', 1.00, 5.00, 1.00),
        (v_prin, 'WHISKY B&W Lt', 'ml', 1000.00, 5.00, 1.00),
        (v_prin, 'RON SUPERIOR Lt', 'ml', 1000.00, 5.00, 1.00),
        (v_prin, 'TRULULU (Mediano)', 'gr', 300.00, 5.00, 1.00),
        (v_prin, 'LECHE EVAPORADA (2)', 'gr', 354.00, 5.00, 1.00),
        (v_prin, 'NESTEA LIMON', 'gr', 1000.00, 5.00, 1.00),
        (v_prin, 'NESTEA DURZNO', 'gr', 1000.00, 5.00, 1.00),
        (v_prin, 'CEREZA 240g', 'gr', 240.00, 5.00, 1.00),
        (v_prin, 'LICOR DE PIÑA', 'ml', 700.00, 5.00, 1.00),
        (v_prin, 'VINIO ROSSO', 'ml', 750.00, 5.00, 1.00)
    ON CONFLICT (sede_id, nombre) DO UPDATE SET
        unidad_medida = EXCLUDED.unidad_medida;

END $$;
