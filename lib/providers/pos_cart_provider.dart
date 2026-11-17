import 'package:flutter_riverpod/legacy.dart';
import '../models/movimiento_model.dart';
import '../models/presentacion_model.dart';

class CartItem {
  final PresentacionVenta presentacion;
  int cantidad;
  String? notas;

  CartItem({
    required this.presentacion,
    this.cantidad = 1,
    this.notas,
  });

  double get subtotal => cantidad * presentacion.precioVigente;
}

class PosCartState {
  final List<CartItem> items;
  final MetodoPago metodoPago;
  final CanalVenta canal;
  final TipoOperacionVenta tipoOperacion;
  final String clienteNombre;
  final String clienteCedula;
  final String notas;
  final double descuento;
  final bool isLoading;

  PosCartState({
    this.items = const [],
    this.metodoPago = MetodoPago.efectivoUsd,
    this.canal = CanalVenta.barra,
    this.tipoOperacion = TipoOperacionVenta.venta,
    this.clienteNombre = '',
    this.clienteCedula = '',
    this.notas = '',
    this.descuento = 0.0,
    this.isLoading = false,
  });

  double get subtotal =>
      items.fold(0.0, (acc, item) => acc + item.subtotal);

  double get total => (subtotal - descuento).clamp(0.0, double.infinity);

  int get totalUnidades =>
      items.fold(0, (acc, item) => acc + item.cantidad);

  PosCartState copyWith({
    List<CartItem>? items,
    MetodoPago? metodoPago,
    CanalVenta? canal,
    TipoOperacionVenta? tipoOperacion,
    String? clienteNombre,
    String? clienteCedula,
    String? notas,
    double? descuento,
    bool? isLoading,
  }) {
    return PosCartState(
      items: items ?? this.items,
      metodoPago: metodoPago ?? this.metodoPago,
      canal: canal ?? this.canal,
      tipoOperacion: tipoOperacion ?? this.tipoOperacion,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      clienteCedula: clienteCedula ?? this.clienteCedula,
      notas: notas ?? this.notas,
      descuento: descuento ?? this.descuento,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PosCartNotifier extends StateNotifier<PosCartState> {
  PosCartNotifier() : super(PosCartState());

  void agregarPresentacion(PresentacionVenta p) {
    final index = state.items.indexWhere((it) => it.presentacion.id == p.id);
    if (index >= 0) {
      final updatedList = List<CartItem>.from(state.items);
      updatedList[index].cantidad += 1;
      state = state.copyWith(items: updatedList);
    } else {
      state = state.copyWith(
        items: [...state.items, CartItem(presentacion: p, cantidad: 1)],
      );
    }
  }

  void reducirCantidad(String presentacionId) {
    final index = state.items.indexWhere((it) => it.presentacion.id == presentacionId);
    if (index >= 0) {
      final updatedList = List<CartItem>.from(state.items);
      if (updatedList[index].cantidad > 1) {
        updatedList[index].cantidad -= 1;
        state = state.copyWith(items: updatedList);
      } else {
        eliminarItem(presentacionId);
      }
    }
  }

  void eliminarItem(String presentacionId) {
    state = state.copyWith(
      items: state.items.where((it) => it.presentacion.id != presentacionId).toList(),
    );
  }

  void setMetodoPago(MetodoPago m) => state = state.copyWith(metodoPago: m);
  void setCanal(CanalVenta c) => state = state.copyWith(canal: c);
  void setTipoOperacion(TipoOperacionVenta t) => state = state.copyWith(tipoOperacion: t);
  void setClienteNombre(String c) => state = state.copyWith(clienteNombre: c);
  void setClienteCedula(String c) => state = state.copyWith(clienteCedula: c);
  void setCliente({required String nombre, String? cedula}) =>
      state = state.copyWith(clienteNombre: nombre, clienteCedula: cedula ?? '');
  void setNotas(String n) => state = state.copyWith(notas: n);
  void setDescuento(double d) => state = state.copyWith(descuento: d);
  void setLoading(bool loading) => state = state.copyWith(isLoading: loading);

  void limpiarCarrito() {
    state = PosCartState();
  }
}

final posCartProvider = StateNotifierProvider<PosCartNotifier, PosCartState>((ref) {
  return PosCartNotifier();
});
