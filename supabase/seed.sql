-- ==============================================================================
-- DATOS SEMILLA IDEMPOTENTES: CONTROL DE VENTAS, BARRA E INVENTARIO
-- Archivo: supabase/seed.sql
-- ==============================================================================

-- 1. POBLAR PRODUCTOS BASE (productos)
INSERT INTO public.productos (codigo, nombre, descripcion, categoria, unidad_medida, costo_unitario, es_inventariable, stock_actual, stock_minimo)
VALUES
    -- Cervezas e Insumos Físicos de Alta Rotación (Inventariables)
    ('PROD-CERV-ZULIA', 'Cerveza Zulia', 'Botella retornable 222ml / tercio', 'CERVEZA', 'UND', 0.8500, true, 150.00, 36.00),
    ('PROD-CERV-POLAR-NEGRA', 'Cerveza Polar Negra', 'Botella Polar Negra 222ml', 'CERVEZA', 'UND', 0.8500, true, 120.00, 36.00),
    ('PROD-CERV-POLAR-LIGHT', 'Cerveza Polar Light', 'Botella Polar Light 222ml', 'CERVEZA', 'UND', 0.8500, true, 180.00, 36.00),
    ('PROD-CERV-SOLERA', 'Cerveza Solera', 'Solera Verde / Clásica botella', 'CERVEZA', 'UND', 1.0000, true, 90.00, 36.00),
    ('PROD-CERV-ZULIA-LATA', 'Cerveza Zulia Lata', 'Cerveza Zulia en lata 295ml/355ml', 'CERVEZA', 'LATA', 1.3000, true, 72.00, 24.00),
    ('PROD-LICOR-CARORENA-LATA', 'Caroreña Lata', 'Sangría Caroreña Verano en lata', 'LICOR', 'LATA', 1.3000, true, 60.00, 24.00),
    ('PROD-LICOR-WHISKY-8Y', 'Whisky 8 Años', 'Botella de Whisky estándar 8 años', 'LICOR', 'UND', 18.0000, true, 12.00, 3.00),
    ('PROD-LICOR-WHISKY-12Y', 'Whisky 12 Años', 'Botella de Whisky premium 12 años', 'LICOR', 'UND', 28.0000, true, 10.00, 2.00),

    -- Cócteles, Bebidas Preparadas y Servicios
    ('PROD-COCTEL-MOJITO', 'Mojito Cubano', 'Cóctel artesanal con ron, hierbabuena y soda', 'COCTEL', 'COPA', 1.2000, false, 0.00, 0.00),
    ('PROD-COCTEL-PINA-COLADA', 'Piña Colada', 'Cóctel cremoso con ron, piña y crema de coco', 'COCTEL', 'COPA', 1.5000, false, 0.00, 0.00),
    ('PROD-COCTEL-CUBA-LIBRE', 'Cuba Libre', 'Ron oscuro, cola y limón', 'COCTEL', 'VASO', 1.1000, false, 0.00, 0.00),
    ('PROD-COCTEL-GRINCH', 'Grinch', 'Cóctel especial cítrico verde a base de licor de melón y vodka', 'COCTEL', 'COPA', 1.5000, false, 0.00, 0.00),
    ('PROD-COCTEL-DAIQUIRI', 'Daiquiri', 'Ron blanco, azúcar y zumo de limón/fruta', 'COCTEL', 'COPA', 1.3000, false, 0.00, 0.00),
    ('PROD-COCTEL-PANTERA-ROSA', 'Pantera Rosa', 'Cóctel dulce frutal cremoso', 'COCTEL', 'COPA', 1.5000, false, 0.00, 0.00),
    ('PROD-COCTEL-LAGUNA-AZUL', 'Laguna Azul', 'Vodka, blue curacao y refresco de limón', 'COCTEL', 'COPA', 1.4000, false, 0.00, 0.00),
    ('PROD-COCTEL-SANGRIA', 'Sangría', 'Sangría de la casa servida en copa con frutas', 'COCTEL', 'COPA', 1.2000, false, 0.00, 0.00),
    ('PROD-BEB-JUGO-FRESA', 'Jugo Fresa', 'Jugo natural de fresa frappé', 'BEBIDA_NO_ALCOHOLICA', 'VASO', 0.8000, false, 0.00, 0.00),
    ('PROD-BEB-MALTEADA', 'Malteada', 'Malteada cremosa de chocolate/vainilla', 'BEBIDA_NO_ALCOHOLICA', 'VASO', 1.0000, false, 0.00, 0.00),
    ('PROD-BEB-NESTEA', 'Nestea', 'Té frío de limón Nestea en vaso con hielo', 'BEBIDA_NO_ALCOHOLICA', 'VASO', 0.4000, false, 0.00, 0.00),
    ('PROD-SRV-DESCORCHE', 'Descolche', 'Servicio de descorche de botella de licor externa', 'SERVICIO', 'SRV', 0.0000, false, 0.00, 0.00)
ON CONFLICT (codigo) DO UPDATE SET
    nombre = EXCLUDED.nombre,
    descripcion = EXCLUDED.descripcion,
    categoria = EXCLUDED.categoria,
    unidad_medida = EXCLUDED.unidad_medida,
    costo_unitario = EXCLUDED.costo_unitario,
    es_inventariable = EXCLUDED.es_inventariable;

-- 2. POBLAR PRESENTACIONES DE VENTA (presentaciones_venta)
INSERT INTO public.presentaciones_venta (codigo, nombre, descripcion, categoria, canal_venta)
VALUES
    -- Presentaciones Individuales
    ('PRES-ZULIA-UND', 'CERVEZA ZULIA INDIVIDUAL', 'Cerveza Zulia unidad 222ml', 'CERVEZA', 'BARRA'),
    ('PRES-POLAR-NEGRA-UND', 'CERVEZA POLAR NEGRA INDIVIDUAL', 'Cerveza Polar Negra unidad 222ml', 'CERVEZA', 'BARRA'),
    ('PRES-POLAR-LIGHT-UND', 'CERVEZA POLAR LIGHT INDIVIDUAL', 'Cerveza Polar Light unidad 222ml', 'CERVEZA', 'BARRA'),
    ('PRES-SOLERA-UND', 'CERVEZA SOLERA INDIVIDUAL', 'Cerveza Solera Verde unidad 222ml', 'CERVEZA', 'BARRA'),
    ('PRES-ZULIA-LATA-UND', 'CERVEZA ZULIA LATA', 'Cerveza Zulia en lata individual', 'CERVEZA', 'BARRA'),
    ('PRES-CARORENA-LATA-UND', 'CAROREÑA LATA', 'Sangría Caroreña en lata individual', 'LICOR', 'BARRA'),
    ('PRES-WHISKY-8Y-TRAGO', 'TRAGO WHISKY 8 AÑOS', 'Trago individual servido en vaso rocas', 'LICOR', 'BARRA'),
    ('PRES-WHISKY-12Y-TRAGO', 'TRAGO WHISKY 12 AÑOS', 'Trago individual de whisky 12 años premium', 'LICOR', 'BARRA'),

    -- Cócteles, Jugos y Servicios
    ('PRES-MOJITO', 'MOJITO CUBANO', 'Mojito Cubano preparado', 'COCTEL', 'BARRA'),
    ('PRES-PINA-COLADA', 'PIÑA COLADA', 'Piña Colada cremosa', 'COCTEL', 'BARRA'),
    ('PRES-CUBA-LIBRE', 'CUBA LIBRE', 'Cuba Libre clásico', 'COCTEL', 'BARRA'),
    ('PRES-GRINCH', 'GRINCH', 'Cóctel verde especial Grinch', 'COCTEL', 'BARRA'),
    ('PRES-DAIQUIRI', 'DAIQUIRI', 'Daiquiri clásico o de fruta', 'COCTEL', 'BARRA'),
    ('PRES-PANTERA-ROSA', 'PANTERA ROSA', 'Cóctel Pantera Rosa dulce', 'COCTEL', 'BARRA'),
    ('PRES-LAGUNA-AZUL', 'LAGUNA AZUL', 'Cóctel Laguna Azul refrescante', 'COCTEL', 'BARRA'),
    ('PRES-SANGRIA', 'SANGRÍA', 'Copa de Sangría de la casa', 'COCTEL', 'BARRA'),
    ('PRES-JUGO-FRESA', 'JUGO FRESA', 'Vaso de jugo de fresa natural', 'BEBIDA_NO_ALCOHOLICA', 'BARRA'),
    ('PRES-MALTEADA', 'MALTEADA', 'Vaso de malteada batida', 'BEBIDA_NO_ALCOHOLICA', 'BARRA'),
    ('PRES-NESTEA', 'NESTEA', 'Vaso de Nestea con hielo', 'BEBIDA_NO_ALCOHOLICA', 'BARRA'),
    ('PRES-DESCORCHE', 'DESCOLCHE', 'Cobro de servicio por descorche de botella traída por cliente', 'SERVICIO', 'BARRA'),

    -- Baldes y Cajas Agrupadas (Multi-unidades / Desconsolidación)
    ('PRES-1-2-BALDE-CERVEZA', '1/2 BALDE CERVEZA', 'Medio balde con 5 cervezas frías', 'CERVEZA', 'BARRA'),
    ('PRES-BALDE-ZULIA', 'BALDE CERVEZA ZULIA', 'Balde de 10 Cervezas Zulia con hielo', 'CERVEZA', 'BARRA'),
    ('PRES-BALDE-POLAR-NEGRA', 'BALDE CERVEZA POLAR NEGRA', 'Balde de 10 Cervezas Polar Negra con hielo', 'CERVEZA', 'BARRA'),
    ('PRES-BALDE-POLAR-LIGHT', 'BALDE CERVEZA POLAR LIGHT', 'Balde de 10 Cervezas Polar Light con hielo', 'CERVEZA', 'BARRA'),
    ('PRES-BALDE-SOLERA', 'BALDE CERVEZA SOLERA', 'Balde de 10 Cervezas Solera Verde con hielo', 'CERVEZA', 'BARRA'),
    ('PRES-BALDE-RESERVACION', 'BALDE CERVEZA RESERVACION', 'Balde de 10 cervezas exclusivo canal reservación', 'CERVEZA', 'RESERVACION'),
    ('PRES-1-2-CAJA-CERVEZA', '1/2 CAJA CERVEZA', 'Media caja de cerveza (18 unidades)', 'CERVEZA', 'BARRA'),
    ('PRES-CAJA-CERVEZA-36', 'CAJA CERVEZA (36 UND)', 'Caja completa de cerveza con 36 botellas', 'CERVEZA', 'BARRA')
ON CONFLICT (codigo) DO UPDATE SET
    nombre = EXCLUDED.nombre,
    descripcion = EXCLUDED.descripcion,
    categoria = EXCLUDED.categoria,
    canal_venta = EXCLUDED.canal_venta;

-- 3. POBLAR RECETAS Y EQUIVALENCIAS (recetas_equivalencias)
-- Vinculación inequívoca entre presentación comercial e insumo físico descontable
INSERT INTO public.recetas_equivalencias (presentacion_id, producto_id, factor_unidades_u, es_ingrediente_principal, notas)
SELECT 
    pv.id AS presentacion_id,
    pr.id AS producto_id,
    map.factor,
    true,
    map.nota
FROM (
    VALUES
        -- Unidades Individuales (factor 1.0)
        ('PRES-ZULIA-UND', 'PROD-CERV-ZULIA', 1.0000, '1 Botella Cerveza Zulia'),
        ('PRES-POLAR-NEGRA-UND', 'PROD-CERV-POLAR-NEGRA', 1.0000, '1 Botella Polar Negra'),
        ('PRES-POLAR-LIGHT-UND', 'PROD-CERV-POLAR-LIGHT', 1.0000, '1 Botella Polar Light'),
        ('PRES-SOLERA-UND', 'PROD-CERV-SOLERA', 1.0000, '1 Botella Solera'),
        ('PRES-ZULIA-LATA-UND', 'PROD-CERV-ZULIA-LATA', 1.0000, '1 Lata Cerveza Zulia'),
        ('PRES-CARORENA-LATA-UND', 'PROD-LICOR-CARORENA-LATA', 1.0000, '1 Lata Caroreña'),
        ('PRES-WHISKY-8Y-TRAGO', 'PROD-LICOR-WHISKY-8Y', 1.0000, '1 Trago Whisky 8 Años'),
        ('PRES-WHISKY-12Y-TRAGO', 'PROD-LICOR-WHISKY-12Y', 1.0000, '1 Trago Whisky 12 Años'),

        -- Cócteles y Jugos (factor 1.0 a producto conceptual)
        ('PRES-MOJITO', 'PROD-COCTEL-MOJITO', 1.0000, 'Porción cóctel Mojito'),
        ('PRES-PINA-COLADA', 'PROD-COCTEL-PINA-COLADA', 1.0000, 'Porción cóctel Piña Colada'),
        ('PRES-CUBA-LIBRE', 'PROD-COCTEL-CUBA-LIBRE', 1.0000, 'Porción cóctel Cuba Libre'),
        ('PRES-GRINCH', 'PROD-COCTEL-GRINCH', 1.0000, 'Porción cóctel Grinch'),
        ('PRES-DAIQUIRI', 'PROD-COCTEL-DAIQUIRI', 1.0000, 'Porción cóctel Daiquiri'),
        ('PRES-PANTERA-ROSA', 'PROD-COCTEL-PANTERA-ROSA', 1.0000, 'Porción cóctel Pantera Rosa'),
        ('PRES-LAGUNA-AZUL', 'PROD-COCTEL-LAGUNA-AZUL', 1.0000, 'Porción cóctel Laguna Azul'),
        ('PRES-SANGRIA', 'PROD-COCTEL-SANGRIA', 1.0000, 'Porción copa Sangría'),
        ('PRES-JUGO-FRESA', 'PROD-BEB-JUGO-FRESA', 1.0000, 'Porción jugo fresa'),
        ('PRES-MALTEADA', 'PROD-BEB-MALTEADA', 1.0000, 'Porción malteada'),
        ('PRES-NESTEA', 'PROD-BEB-NESTEA', 1.0000, 'Porción vaso Nestea'),
        ('PRES-DESCORCHE', 'PROD-SRV-DESCORCHE', 1.0000, 'Servicio descolche'),

        -- Baldes y Cervezas Múltiples (factores 5, 10, 18, 36)
        ('PRES-1-2-BALDE-CERVEZA', 'PROD-CERV-ZULIA', 5.0000, 'Descuenta 5 botellas de cerveza Zulia'),
        ('PRES-BALDE-ZULIA', 'PROD-CERV-ZULIA', 10.0000, 'Descuenta 10 botellas de cerveza Zulia'),
        ('PRES-BALDE-POLAR-NEGRA', 'PROD-CERV-POLAR-NEGRA', 10.0000, 'Descuenta 10 botellas Polar Negra'),
        ('PRES-BALDE-POLAR-LIGHT', 'PROD-CERV-POLAR-LIGHT', 10.0000, 'Descuenta 10 botellas Polar Light'),
        ('PRES-BALDE-SOLERA', 'PROD-CERV-SOLERA', 10.0000, 'Descuenta 10 botellas Solera'),
        ('PRES-BALDE-RESERVACION', 'PROD-CERV-ZULIA', 10.0000, 'Descuenta 10 botellas Zulia por reservación'),
        ('PRES-1-2-CAJA-CERVEZA', 'PROD-CERV-ZULIA', 18.0000, 'Descuenta 18 botellas (media caja)'),
        ('PRES-CAJA-CERVEZA-36', 'PROD-CERV-ZULIA', 36.0000, 'Descuenta 36 botellas (caja completa)')
) AS map(cod_pres, cod_prod, factor, nota)
JOIN public.presentaciones_venta pv ON pv.codigo = map.cod_pres
JOIN public.productos pr ON pr.codigo = map.cod_prod
ON CONFLICT (presentacion_id, producto_id) DO UPDATE SET
    factor_unidades_u = EXCLUDED.factor_unidades_u,
    notas = EXCLUDED.notas;

-- 4. POBLAR PRECIOS VIGENTES (historial_precios)
-- Tarifas vigentes: Cervezas 1.20, Solera 1.40, Lata 2.00, Baldes 10.00, Balde Solera 12.00, Balde Reservación 9.00, Caja 30.00, Cócteles 3.50 a 5.00
INSERT INTO public.historial_precios (presentacion_id, precio_unitario, fecha_desde, activo)
SELECT 
    pv.id AS presentacion_id,
    precios.precio,
    timezone('utc'::text, now()),
    true
FROM (
    VALUES
        ('PRES-ZULIA-UND', 1.20),
        ('PRES-POLAR-NEGRA-UND', 1.20),
        ('PRES-POLAR-LIGHT-UND', 1.20),
        ('PRES-SOLERA-UND', 1.40),
        ('PRES-ZULIA-LATA-UND', 2.00),
        ('PRES-CARORENA-LATA-UND', 2.00),
        ('PRES-WHISKY-8Y-TRAGO', 3.50),
        ('PRES-WHISKY-12Y-TRAGO', 5.00),

        -- Baldes y cajas
        ('PRES-1-2-BALDE-CERVEZA', 5.50),
        ('PRES-BALDE-ZULIA', 10.00),
        ('PRES-BALDE-POLAR-NEGRA', 10.00),
        ('PRES-BALDE-POLAR-LIGHT', 10.00),
        ('PRES-BALDE-SOLERA', 12.00),
        ('PRES-BALDE-RESERVACION', 9.00),
        ('PRES-1-2-CAJA-CERVEZA', 16.00),
        ('PRES-CAJA-CERVEZA-36', 30.00),

        -- Cócteles y Jugos (entre 3.50 y 5.00)
        ('PRES-MOJITO', 4.00),
        ('PRES-PINA-COLADA', 4.50),
        ('PRES-CUBA-LIBRE', 3.50),
        ('PRES-GRINCH', 4.50),
        ('PRES-DAIQUIRI', 4.00),
        ('PRES-PANTERA-ROSA', 4.50),
        ('PRES-LAGUNA-AZUL', 4.50),
        ('PRES-SANGRIA', 4.00),
        ('PRES-JUGO-FRESA', 3.50),
        ('PRES-MALTEADA', 4.00),
        ('PRES-NESTEA', 2.00),
        ('PRES-DESCORCHE', 5.00)
) AS precios(cod_pres, precio)
JOIN public.presentaciones_venta pv ON pv.codigo = precios.cod_pres
WHERE NOT EXISTS (
    SELECT 1 FROM public.historial_precios hp
    WHERE hp.presentacion_id = pv.id
      AND hp.activo = true
      AND (hp.fecha_hasta IS NULL OR hp.fecha_hasta > timezone('utc'::text, now()))
);
