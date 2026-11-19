import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../core/config/supabase_config.dart';
import '../models/cierre_diario_model.dart';
import '../models/cliente_historial_model.dart';
import '../models/insumo_model.dart';
import '../models/movimiento_kardex_model.dart';
import '../models/movimiento_model.dart';
import '../models/presentacion_model.dart';
import '../models/producto_model.dart';
import '../services/cierre_service.dart';
import '../services/comandas_service.dart';
import '../services/insumos_service.dart';
import '../services/productos_service.dart';
import '../services/ventas_service.dart';

// Servicios
final productosServiceProvider = Provider((ref) => ProductosService());
final ventasServiceProvider = Provider((ref) => VentasService());
final cierreServiceProvider = Provider((ref) => CierreService());
final insumosServiceProvider = Provider((ref) => InsumosService());
final comandasServiceProvider = Provider((ref) => ComandasService());

// Insumos y Kardex
final insumosFiltroUnidadProvider = StateProvider<String?>((ref) => null);
final insumosBusquedaProvider = StateProvider<String>((ref) => '');

final listaInsumosProvider =
    FutureProvider.autoDispose<List<Insumo>>((ref) async {
  final service = ref.watch(insumosServiceProvider);
  final unidad = ref.watch(insumosFiltroUnidadProvider);
  final search = ref.watch(insumosBusquedaProvider);
  return service.getInsumos(search: search, unidad: unidad);
});

final movimientosKardexRecientesProvider =
    FutureProvider.autoDispose<List<MovimientoKardex>>((ref) async {
  final service = ref.watch(insumosServiceProvider);
  return service.getMovimientosKardex(limit: 50);
});

// Resumen de Turno
final resumenTurnoFechaProvider =
    StateProvider<DateTime>((ref) => DateTime.now());

final resumenTurnoProvider =
    FutureProvider.autoDispose<ResumenTurnoData>((ref) async {
  final service = ref.watch(comandasServiceProvider);
  final fecha = ref.watch(resumenTurnoFechaProvider);
  return service.getResumenTurno(fecha: fecha);
});

// Categorías dinámicas desde Supabase
final categoriasDbListProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  try {
    final res = await SupabaseConfig.client
        .from('categorias')
        .select('nombre')
        .eq('activo', true)
        .order('nombre');
    return (res as List).map((e) => e['nombre'] as String).toList();
  } catch (_) {
    return ['Cervezas', 'Cócteles', 'Licores & Destilados', 'Sin Alcohol & Jugos', 'Otros'];
  }
});

// Filtros para Catálogo POS
final catalogoFiltroCategoriaNombreProvider =
    StateProvider<String?>((ref) => null);
final catalogoFiltroCategoriaProvider =
    StateProvider<CategoriaProducto?>((ref) => null);
final catalogoFiltroCanalProvider =
    StateProvider<CanalVenta>((ref) => CanalVenta.barra);
final catalogoBusquedaProvider = StateProvider<String>((ref) => '');

// Catálogo Comercial de Ventas
final catalogoVentasProvider =
    FutureProvider.autoDispose<List<PresentacionVenta>>((ref) async {
  final ventasService = ref.watch(ventasServiceProvider);
  final categoriaNombre = ref.watch(catalogoFiltroCategoriaNombreProvider);
  final categoria = ref.watch(catalogoFiltroCategoriaProvider);
  final canal = ref.watch(catalogoFiltroCanalProvider);
  final search = ref.watch(catalogoBusquedaProvider);

  return ventasService.getCatalogoVenta(
    categoria: categoria,
    categoriaNombre: categoriaNombre,
    canal: canal,
    search: search,
  );
});

// Catálogo completo sin filtros para buscador de comanda
final catalogoCompletoVentasProvider =
    FutureProvider.autoDispose<List<PresentacionVenta>>((ref) async {
  final ventasService = ref.watch(ventasServiceProvider);
  return ventasService.getCatalogoVenta();
});

// Filtros para Inventario
final inventarioFiltroCategoriaProvider =
    StateProvider<CategoriaProducto?>((ref) => null);
final inventarioBusquedaProvider = StateProvider<String>((ref) => '');

// Lista de Inventario Físico
final inventarioProductosProvider =
    FutureProvider.autoDispose<List<Producto>>((ref) async {
  final service = ref.watch(productosServiceProvider);
  final categoria = ref.watch(inventarioFiltroCategoriaProvider);
  final search = ref.watch(inventarioBusquedaProvider);

  return service.getProductos(
    categoria: categoria,
    search: search,
  );
});

// Últimas Ventas / Tickets
final ultimasVentasProvider =
    FutureProvider.autoDispose<List<Movimiento>>((ref) async {
  final service = ref.watch(ventasServiceProvider);
  return service.getUltimasVentas();
});

// Cierre Diario del Día Seleccionado
final fechaCierreSeleccionadaProvider =
    StateProvider<DateTime>((ref) => DateTime.now());

final arqueoCierreProvider =
    FutureProvider.autoDispose<List<CierreDiarioItem>>((ref) async {
  final service = ref.watch(cierreServiceProvider);
  final fecha = ref.watch(fechaCierreSeleccionadaProvider);
  return service.generarCierreDiario(fecha: fecha);
});

// Clientes con Compras Registradas en Barra
final clientesRegistradosProvider =
    FutureProvider.autoDispose<List<ClienteHistorial>>((ref) async {
  final service = ref.watch(ventasServiceProvider);
  return service.getClientesConCompras();
});

// Búsqueda interactiva de clientes
final clienteBusquedaQueryProvider = StateProvider<String>((ref) => '');

final clientesFiltradosProvider =
    FutureProvider.autoDispose<List<ClienteHistorial>>((ref) async {
  final service = ref.watch(ventasServiceProvider);
  final query = ref.watch(clienteBusquedaQueryProvider);
  return service.getClientesConCompras(search: query);
});
