import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/config/supabase_config.dart';
import '../models/cliente_historial_model.dart';
import '../models/movimiento_model.dart';
import '../models/presentacion_model.dart';
import '../models/producto_model.dart';

class VentasService {
  final SupabaseClient _client = SupabaseConfig.client;
  final _uuid = const Uuid();

  /// Obtiene el catálogo comercial de presentaciones con precios vigentes y recetas
  Future<List<PresentacionVenta>> getCatalogoVenta({
    CategoriaProducto? categoria,
    CanalVenta? canal,
    String? search,
  }) async {
    // Consultamos la vista de precios vigentes
    var query = _client.from('vista_precios_vigentes').select();

    if (categoria != null) {
      query = query.eq('categoria', categoria.dbValue);
    }
    if (canal != null) {
      query = query.eq('canal_venta', canal.dbValue);
    }
    if (search != null && search.trim().isNotEmpty) {
      query = query.ilike('nombre', '%$search%');
    }

    final data = await query.order('categoria').order('nombre');
    final presentaciones = (data as List)
        .map((e) => PresentacionVenta.fromJson(e as Map<String, dynamic>))
        .toList();

    // Traer recetas y equivalencias para desconsolidación visual
    if (presentaciones.isNotEmpty) {
      final ids = presentaciones.map((p) => p.id).toList();
      final recetasData = await _client
          .from('recetas_equivalencias')
          .select('*, productos(*)')
          .inFilter('presentacion_id', ids);

      final Map<String, List<RecetaEquivalencia>> recetasMap = {};
      for (final r in (recetasData as List)) {
        final item = RecetaEquivalencia.fromJson(r as Map<String, dynamic>);
        recetasMap.putIfAbsent(item.presentacionId, () => []).add(item);
      }

      return presentaciones.map((p) {
        return p.copyWith(equivalencias: recetasMap[p.id] ?? []);
      }).toList();
    }

    return presentaciones;
  }

  /// Crea una comanda/venta en la barra
  /// Al insertar los detalles, los triggers de Supabase descuentan automáticamente el stock físico
  Future<Movimiento> registrarVenta({
    required List<DetalleMovimiento> items,
    required MetodoPago metodoPago,
    required CanalVenta canal,
    TipoOperacionVenta tipoOperacion = TipoOperacionVenta.venta,
    String? clienteNombre,
    String? clienteCedula,
    String? notas,
    double descuento = 0.0,
  }) async {
    final now = DateTime.now();
    final String timestampStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final String randomSuffix = _uuid.v4().substring(0, 4).toUpperCase();
    final String ticketNumber = 'TICK-$timestampStr-$randomSuffix';

    double subtotal = 0.0;
    for (var it in items) {
      subtotal += (it.cantidad * it.precioUnitario);
    }
    final double total = (subtotal - descuento).clamp(0.0, double.infinity);

    // 1. Insertar movimiento principal
    final movRes = await _client
        .from('movimientos')
        .insert({
          'numero_ticket': ticketNumber,
          'fecha_operacion': now.toUtc().toIso8601String(),
          'tipo_operacion': tipoOperacion.dbValue,
          'canal': canal.dbValue,
          'estado': 'CONFIRMADO',
          'metodo_pago': metodoPago.dbValue,
          'subtotal': subtotal,
          'descuento': descuento,
          'total': total,
          'cliente_nombre': clienteNombre,
          'cliente_cedula': clienteCedula,
          'notas': notas,
        })
        .select()
        .single();

    final String movimientoId = movRes['id'] as String;

    // 2. Insertar detalles
    final detallesData = items.map((item) {
      return {
        'movimiento_id': movimientoId,
        'presentacion_id': item.presentacionId,
        'cantidad': item.cantidad,
        'precio_unitario': item.precioUnitario,
        'subtotal': item.cantidad * item.precioUnitario,
        'notas': item.notas,
      };
    }).toList();

    await _client.from('detalle_movimientos').insert(detallesData);

    return Movimiento.fromJson(movRes);
  }

  /// Consulta las últimas comandas registradas
  Future<List<Movimiento>> getUltimasVentas({int limit = 20}) async {
    final data = await _client
        .from('movimientos')
        .select('*, detalle_movimientos(*, presentaciones_venta(nombre))')
        .order('fecha_operacion', ascending: false)
        .limit(limit);

    return (data as List).map((e) => Movimiento.fromJson(e)).toList();
  }

  /// Obtiene los clientes con compras registradas previamente (búsqueda por nombre o cédula)
  Future<List<ClienteHistorial>> getClientesConCompras({String? search}) async {
    try {
      var query = _client.from('vista_clientes_resumen').select();
      if (search != null && search.trim().isNotEmpty) {
        final term = search.trim();
        query = query.or('cliente_nombre.ilike.%$term%,cliente_cedula.ilike.%$term%');
      }
      final data = await query.order('ultima_compra', ascending: false).limit(50);
      return (data as List).map((e) => ClienteHistorial.fromJson(e)).toList();
    } catch (_) {
      // Fallback a consulta directa sobre la tabla movimientos
      try {
        var query = _client
            .from('movimientos')
            .select('cliente_nombre, cliente_cedula, numero_ticket, total, fecha_operacion')
            .not('cliente_nombre', 'is', null)
            .neq('cliente_nombre', '');
        if (search != null && search.trim().isNotEmpty) {
          final term = search.trim();
          query = query.or('cliente_nombre.ilike.%$term%,cliente_cedula.ilike.%$term%');
        }
        final data = await query.order('fecha_operacion', ascending: false).limit(100);

        final Map<String, List<Map<String, dynamic>>> grouped = {};
        for (final row in (data as List)) {
          final name = (row['cliente_nombre'] as String?)?.trim();
          if (name != null && name.isNotEmpty) {
            grouped.putIfAbsent(name, () => []).add(row as Map<String, dynamic>);
          }
        }

        final List<ClienteHistorial> list = [];
        grouped.forEach((name, rows) {
          final first = rows.first;
          double total = 0.0;
          for (final r in rows) {
            total += (r['total'] as num?)?.toDouble() ?? 0.0;
          }
          list.add(ClienteHistorial(
            nombre: name,
            cedula: first['cliente_cedula'] as String?,
            totalCompras: rows.length,
            ultimaCompra: first['fecha_operacion'] != null
                ? DateTime.tryParse(first['fecha_operacion'] as String)
                : null,
            totalGastado: total,
            ultimoTicket: first['numero_ticket'] as String?,
          ));
        });
        return list;
      } catch (e) {
        return [];
      }
    }
  }
}
