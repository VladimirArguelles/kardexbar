import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../models/producto_model.dart';

class ProductosService {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Obtiene todos los productos inventariables y activos
  Future<List<Producto>> getProductos({String? search, CategoriaProducto? categoria}) async {
    var query = _client.from('productos').select().eq('activo', true);

    if (categoria != null) {
      query = query.eq('categoria', categoria.dbValue);
    }

    if (search != null && search.trim().isNotEmpty) {
      query = query.ilike('nombre', '%$search%');
    }

    final data = await query.order('categoria').order('nombre');
    return (data as List).map((e) => Producto.fromJson(e)).toList();
  }

  /// Registra una entrada rápida de surtido de bodega a barra
  Future<void> registrarEntradaSurtido({
    required String productoId,
    required double cantidad,
    required String motivo,
  }) async {
    // 1. Obtener producto actual
    final prodData = await _client
        .from('productos')
        .select('stock_actual')
        .eq('id', productoId)
        .single();
    final double stockAnterior = (prodData['stock_actual'] as num).toDouble();
    final double nuevoStock = stockAnterior + cantidad;

    // 2. Actualizar stock en productos
    await _client.from('productos').update({
      'stock_actual': nuevoStock,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', productoId);

    // 3. Crear traza en movimientos_inventario
    await _client.from('movimientos_inventario').insert({
      'producto_id': productoId,
      'tipo_movimiento': 'ENTRADA_SURTIDO',
      'cantidad': cantidad,
      'stock_anterior': stockAnterior,
      'stock_nuevo': nuevoStock,
      'referencia_origen': 'SURTIDO BARRA',
      'motivo': motivo,
      'fecha_movimiento': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Registra un desperdicio o merma (rotura de botella, etc.)
  Future<void> registrarMerma({
    required String productoId,
    required double cantidad,
    required String motivo,
  }) async {
    final prodData = await _client
        .from('productos')
        .select('stock_actual')
        .eq('id', productoId)
        .single();
    final double stockAnterior = (prodData['stock_actual'] as num).toDouble();
    final double nuevoStock = stockAnterior - cantidad;

    await _client.from('productos').update({
      'stock_actual': nuevoStock,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', productoId);

    await _client.from('movimientos_inventario').insert({
      'producto_id': productoId,
      'tipo_movimiento': 'SALIDA_DESPERDICIO',
      'cantidad': cantidad,
      'stock_anterior': stockAnterior,
      'stock_nuevo': nuevoStock,
      'referencia_origen': 'MERMA BARRA',
      'motivo': motivo,
      'fecha_movimiento': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
