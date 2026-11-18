import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../models/comanda_model.dart';

class DetalleComandaInput {
  final String productoId;
  final String? categoria;
  final double cantidad;
  final double precioUnitario;

  DetalleComandaInput({
    required this.productoId,
    this.categoria,
    required this.cantidad,
    required this.precioUnitario,
  });

  Map<String, dynamic> toJson() {
    return {
      'producto_id': productoId,
      if (categoria != null) 'categoria': categoria,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
    };
  }
}

class ItemResumenCategoria {
  final String productoNombre;
  final String categoria;
  final double cantidadTotal;
  final double precioUnitario;
  final double totalRecaudado;

  ItemResumenCategoria({
    required this.productoNombre,
    required this.categoria,
    required this.cantidadTotal,
    required this.precioUnitario,
    required this.totalRecaudado,
  });
}

class ResumenTurnoData {
  final DateTime fecha;
  final int totalComandas;
  final double totalRecaudado;
  final double totalItemsDespachados;
  final Map<String, List<ItemResumenCategoria>> itemsPorCategoria;

  ResumenTurnoData({
    required this.fecha,
    required this.totalComandas,
    required this.totalRecaudado,
    required this.totalItemsDespachados,
    required this.itemsPorCategoria,
  });
}

class ComandasService {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Registra una comanda de caja con clasificación automática y descuento de insumos
  Future<VentaComanda> registrarComanda({
    required String numeroTicketCaja,
    required List<DetalleComandaInput> items,
    String? clienteNombre,
    String? notas,
  }) async {
    // 1. Usar RPC registrar_comanda_completa si está disponible para atomicidad
    try {
      final res = await _client.rpc('registrar_comanda_completa', params: {
        'p_numero_ticket_caja': numeroTicketCaja,
        'p_items': items.map((i) => i.toJson()).toList(),
        'p_cliente_nombre': clienteNombre,
        'p_notas': notas,
      });

      final comandaId = res['comanda_id'] as String;

      // Consultar la comanda con sus detalles clasificados
      final data = await _client
          .from('ventas_comandas')
          .select('*, detalle_comandas(*, productos(nombre))')
          .eq('id', comandaId)
          .single();

      return VentaComanda.fromJson(data);
    } catch (_) {
      // Fallback a inserción secuencial si el RPC no se pudo resolver
      final nowIso = DateTime.now().toUtc().toIso8601String();
      double totalEstimado = 0.0;
      for (var it in items) {
        totalEstimado += (it.cantidad * it.precioUnitario);
      }

      final header = await _client
          .from('ventas_comandas')
          .insert({
            'numero_ticket_caja': numeroTicketCaja,
            'fecha': nowIso,
            'total': totalEstimado,
            'estado': 'CONFIRMADO',
            'cliente_nombre': clienteNombre,
            'notas': notas,
          })
          .select()
          .single();

      final String comandaId = header['id'] as String;

      final detallesPayload = items.map((it) {
        String cat = it.categoria ?? 'Otros';
        if (cat.toLowerCase().contains('coctel')) {
          cat = 'Cocteles';
        } else if (cat.toLowerCase().contains('jugo') || cat.toLowerCase().contains('no_alcoholica')) {
          cat = 'Jugos';
        } else if (cat.toLowerCase().contains('cerv')) {
          cat = 'Cervezas';
        } else {
          cat = 'Otros';
        }

        return {
          'comanda_id': comandaId,
          'producto_id': it.productoId,
          'categoria_clasificada': cat,
          'cantidad': it.cantidad,
          'precio_unitario': it.precioUnitario,
          'total': it.cantidad * it.precioUnitario,
        };
      }).toList();

      await _client.from('detalle_comandas').insert(detallesPayload);

      final data = await _client
          .from('ventas_comandas')
          .select('*, detalle_comandas(*, productos(nombre))')
          .eq('id', comandaId)
          .single();

      return VentaComanda.fromJson(data);
    }
  }

  /// Obtiene las comandas registradas en el turno
  Future<List<VentaComanda>> getComandasTurno({DateTime? fecha}) async {
    final targetDate = fecha ?? DateTime.now();
    final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day).toUtc().toIso8601String();
    final endOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59).toUtc().toIso8601String();

    final data = await _client
        .from('ventas_comandas')
        .select('*, detalle_comandas(*, productos(nombre))')
        .gte('fecha', startOfDay)
        .lte('fecha', endOfDay)
        .order('fecha', ascending: false);

    return (data as List).map((e) => VentaComanda.fromJson(e)).toList();
  }

  /// Genera el resumen consolidado del turno agrupado por categorías
  Future<ResumenTurnoData> getResumenTurno({DateTime? fecha}) async {
    final comandas = await getComandasTurno(fecha: fecha);

    double totalRecaudado = 0.0;
    double totalItems = 0.0;
    final Map<String, Map<String, ItemResumenCategoria>> agrupado = {
      'Cocteles': {},
      'Jugos': {},
      'Cervezas': {},
      'Otros': {},
    };

    for (final c in comandas) {
      totalRecaudado += c.total;

      for (final d in c.detalles) {
        totalItems += d.cantidad;
        final cat = d.categoriaClasificada;
        final key = d.productoNombre;

        final targetMap = agrupado.putIfAbsent(cat, () => {});
        if (targetMap.containsKey(key)) {
          final prev = targetMap[key]!;
          targetMap[key] = ItemResumenCategoria(
            productoNombre: key,
            categoria: cat,
            cantidadTotal: prev.cantidadTotal + d.cantidad,
            precioUnitario: d.precioUnitario,
            totalRecaudado: prev.totalRecaudado + d.total,
          );
        } else {
          targetMap[key] = ItemResumenCategoria(
            productoNombre: key,
            categoria: cat,
            cantidadTotal: d.cantidad,
            precioUnitario: d.precioUnitario,
            totalRecaudado: d.total,
          );
        }
      }
    }

    final Map<String, List<ItemResumenCategoria>> resultadoFinal = {};
    for (final entry in agrupado.entries) {
      resultadoFinal[entry.key] = entry.value.values.toList()
        ..sort((a, b) => b.cantidadTotal.compareTo(a.cantidadTotal));
    }

    return ResumenTurnoData(
      fecha: fecha ?? DateTime.now(),
      totalComandas: comandas.length,
      totalRecaudado: totalRecaudado,
      totalItemsDespachados: totalItems,
      itemsPorCategoria: resultadoFinal,
    );
  }
}
