import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/cliente_historial_model.dart';
import '../../models/movimiento_model.dart';
import '../../models/presentacion_model.dart';
import '../../models/producto_model.dart';
import '../../providers/app_providers.dart';
import '../../providers/pos_cart_provider.dart';
import '../widgets/product_card.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  late final TextEditingController _clienteCtrl;
  final ScrollController _categoryScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _clienteCtrl = TextEditingController(text: ref.read(posCartProvider).clienteNombre);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _clienteCtrl.dispose();
    _categoryScrollCtrl.dispose();
    super.dispose();
  }

  void _seleccionarCliente(String nombre) {
    _clienteCtrl.text = nombre;
    ref.read(posCartProvider.notifier).setClienteNombre(nombre);
  }

  void _mostrarDialogoBuscarCliente(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _DialogoBuscarCliente(
        onClienteSeleccionado: (cliente) {
          _seleccionarCliente(cliente.nombre);
        },
      ),
    );
  }

  void _procesarVenta() async {
    final cart = ref.read(posCartProvider);
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agregue productos a la comanda antes de despachar'),
          backgroundColor: AppTheme.errorCoral,
        ),
      );
      return;
    }

    ref.read(posCartProvider.notifier).setLoading(true);

    try {
      final ventasService = ref.read(ventasServiceProvider);

      final itemsDetalle = cart.items.map((it) {
        return DetalleMovimiento(
          presentacionId: it.presentacion.id,
          presentacionNombre: it.presentacion.nombre,
          cantidad: it.cantidad.toDouble(),
          precioUnitario: it.presentacion.precioVigente,
          subtotal: it.subtotal,
          notas: it.notas,
        );
      }).toList();

      final movimiento = await ventasService.registrarVenta(
        items: itemsDetalle,
        metodoPago: cart.metodoPago,
        canal: cart.canal,
        tipoOperacion: cart.tipoOperacion,
        clienteNombre: cart.clienteNombre.isNotEmpty ? cart.clienteNombre : null,
        notas: cart.notas.isNotEmpty ? cart.notas : null,
        descuento: cart.descuento,
      );

      ref.read(posCartProvider.notifier).limpiarCarrito();
      _clienteCtrl.clear();
      ref.invalidate(inventarioProductosProvider);
      ref.invalidate(ultimasVentasProvider);
      ref.invalidate(clientesRegistradosProvider);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.check_circle, color: AppTheme.successMint, size: 28),
              SizedBox(width: 8),
              Text('¡Despacho Confirmado!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ticket N°: ${movimiento.numeroTicket}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryAmber,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              if (movimiento.clienteNombre != null && movimiento.clienteNombre!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: AppTheme.secondaryCyan),
                      const SizedBox(width: 6),
                      Text(
                        'Cliente: ${movimiento.clienteNombre}',
                        style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              Text('Total Cobrado: ${Formatters.currency(movimiento.total)}'),
              Text('Método de Pago: ${movimiento.metodoPago.label}'),
              Text('Canal: ${movimiento.canal.label}'),
              const Divider(color: AppTheme.borderLight, height: 24),
              const Text(
                'El inventario físico ha sido descontado automáticamente mediante triggers en Supabase.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar la comanda: $e'),
          backgroundColor: AppTheme.errorCoral,
        ),
      );
    } finally {
      ref.read(posCartProvider.notifier).setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogoAsync = ref.watch(catalogoVentasProvider);
    final cart = ref.watch(posCartProvider);
    final categoriaFiltro = ref.watch(catalogoFiltroCategoriaProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    // Sincronizar el controlador de texto si el estado cambia externamente (ej: al limpiar comanda)
    ref.listen<String>(
      posCartProvider.select((s) => s.clienteNombre),
      (prev, next) {
        if (_clienteCtrl.text != next) {
          _clienteCtrl.text = next;
        }
      },
    );

    return Scaffold(
      body: Row(
        children: [
          // Sección Izquierda: Catálogo de Productos y Filtros
          Expanded(
            flex: isDesktop ? 6 : 10,
            child: Column(
              children: [
                // Barra Superior: Búsqueda y Filtros de Categoría
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppTheme.surface,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                hintText: 'Buscar por cerveza, cóctel, balde...',
                                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                                suffixIcon: _searchCtrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          ref.read(catalogoBusquedaProvider.notifier).state = '';
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (val) {
                                ref.read(catalogoBusquedaProvider.notifier).state = val;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: AppTheme.primaryAmber),
                            tooltip: 'Actualizar catálogo',
                            onPressed: () => ref.invalidate(catalogoVentasProvider),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Filtros Rápidos de Categorías con navegación fluida y sin desbordes
                      Row(
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.chevron_left, color: AppTheme.textSecondary, size: 20),
                            tooltip: 'Desplazar a la izquierda',
                            onPressed: () {
                              _categoryScrollCtrl.animateTo(
                                (_categoryScrollCtrl.offset - 200).clamp(0.0, _categoryScrollCtrl.position.maxScrollExtent),
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              );
                            },
                          ),
                          Expanded(
                            child: ScrollConfiguration(
                              behavior: const MaterialScrollBehavior().copyWith(
                                dragDevices: {
                                  PointerDeviceKind.mouse,
                                  PointerDeviceKind.touch,
                                  PointerDeviceKind.stylus,
                                  PointerDeviceKind.trackpad,
                                },
                              ),
                              child: SingleChildScrollView(
                                controller: _categoryScrollCtrl,
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  children: [
                                    FilterChip(
                                      label: const Text('Todos'),
                                      selected: categoriaFiltro == null,
                                      onSelected: (_) {
                                        ref.read(catalogoFiltroCategoriaProvider.notifier).state = null;
                                      },
                                      selectedColor: AppTheme.primaryAmber,
                                      labelStyle: TextStyle(
                                        color: categoriaFiltro == null ? Colors.black : AppTheme.textPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ...CategoriaProducto.values.map((cat) {
                                      final isSel = categoriaFiltro == cat;
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: FilterChip(
                                          label: Text(cat.label),
                                          selected: isSel,
                                          onSelected: (_) {
                                            ref.read(catalogoFiltroCategoriaProvider.notifier).state =
                                                isSel ? null : cat;
                                          },
                                          selectedColor: AppTheme.primaryAmber,
                                          labelStyle: TextStyle(
                                            color: isSel ? Colors.black : AppTheme.textPrimary,
                                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
                            tooltip: 'Desplazar a la derecha',
                            onPressed: () {
                              _categoryScrollCtrl.animateTo(
                                (_categoryScrollCtrl.offset + 200).clamp(0.0, _categoryScrollCtrl.position.maxScrollExtent),
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Grid de Productos adaptativo
                Expanded(
                  child: catalogoAsync.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return const Center(
                          child: Text(
                            'No se encontraron productos en esta categoría',
                            style: TextStyle(color: AppTheme.textMuted),
                          ),
                        );
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final int crossAxisCount = (constraints.maxWidth / 215).floor().clamp(2, 6);
                          return GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: 0.92,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: items.length,
                            itemBuilder: (context, idx) {
                              final item = items[idx];
                              final inCart = cart.items.firstWhere(
                                (c) => c.presentacion.id == item.id,
                                orElse: () => CartItem(presentacion: item, cantidad: 0),
                              );

                              return ProductCard(
                                presentacion: item,
                                countInCart: inCart.cantidad,
                                onAdd: () {
                                  ref.read(posCartProvider.notifier).agregarPresentacion(item);
                                },
                                onRemove: () {
                                  ref.read(posCartProvider.notifier).reducirCantidad(item.id);
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppTheme.primaryAmber),
                    ),
                    error: (err, _) => Center(
                      child: Text(
                        'Error al cargar catálogo: $err',
                        style: const TextStyle(color: AppTheme.errorCoral),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sección Derecha: Ticket / Carrito POS
          if (isDesktop)
            Container(
              width: 390,
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(left: BorderSide(color: AppTheme.borderLight)),
              ),
              child: _buildComandaSidebar(context, cart),
            ),
        ],
      ),
      bottomNavigationBar: !isDesktop && cart.items.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(12),
              color: AppTheme.surface,
              child: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: AppTheme.surface,
                    builder: (ctx) => SizedBox(
                      height: MediaQuery.of(context).size.height * 0.85,
                      child: _buildComandaSidebar(context, cart),
                    ),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${cart.totalUnidades} ítems en comanda'),
                    Text('Total: ${Formatters.currency(cart.total)}'),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildComandaSidebar(BuildContext context, PosCartState cart) {
    final clientesAsync = ref.watch(clientesRegistradosProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado de la Comanda
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long, color: AppTheme.primaryAmber),
                  const SizedBox(width: 8),
                  const Text(
                    'Comanda de Barra',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (cart.totalUnidades > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryAmber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${cart.totalUnidades}',
                        style: const TextStyle(
                          color: AppTheme.primaryAmber,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (cart.items.isNotEmpty)
                TextButton(
                  onPressed: () {
                    ref.read(posCartProvider.notifier).limpiarCarrito();
                    _clienteCtrl.clear();
                  },
                  child: const Text('Limpiar', style: TextStyle(color: AppTheme.errorCoral)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // WIDGET CLIENTE: Campo de Nombre con Buscador Integrado
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _clienteCtrl,
                decoration: InputDecoration(
                  labelText: 'Cliente / Mesa / Referencia',
                  hintText: 'Ej: Carlos Mendoza, Mesa 4...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.primaryAmber, size: 20),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_clienteCtrl.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: AppTheme.textMuted),
                          tooltip: 'Limpiar nombre',
                          onPressed: () {
                            _clienteCtrl.clear();
                            ref.read(posCartProvider.notifier).setClienteNombre('');
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.person_search_rounded, color: AppTheme.secondaryCyan, size: 22),
                        tooltip: 'Buscar cliente con compras registradas',
                        onPressed: () => _mostrarDialogoBuscarCliente(context),
                      ),
                    ],
                  ),
                ),
                onChanged: (val) {
                  ref.read(posCartProvider.notifier).setClienteNombre(val);
                },
              ),

              // Chips de sugerencia rápida si el campo está vacío, o confirmación si coincide con un cliente registrado
              clientesAsync.maybeWhen(
                data: (clientes) {
                  if (clientes.isEmpty) return const SizedBox.shrink();

                  // Si el cliente actual coincide con uno registrado, mostrar insignia con sus compras
                  final match = clientes.cast<ClienteHistorial?>().firstWhere(
                        (c) => c?.nombre.trim().toLowerCase() == cart.clienteNombre.trim().toLowerCase(),
                        orElse: () => null,
                      );

                  if (match != null && cart.clienteNombre.isNotEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.secondaryCyan.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded, size: 14, color: AppTheme.secondaryCyan),
                            const SizedBox(width: 5),
                            Text(
                              'Cliente registrado: ${match.totalCompras} ${match.totalCompras == 1 ? 'compra' : 'compras'} previas',
                              style: const TextStyle(color: AppTheme.secondaryCyan, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Si el campo está vacío, mostrar accesos rápidos a los clientes frecuentes
                  if (cart.clienteNombre.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Text(
                              'Frecuentes: ',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                            ),
                            ...clientes.take(3).map((cl) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _seleccionarCliente(cl.nombre),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppTheme.borderLight),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.history, size: 12, color: AppTheme.primaryAmber),
                                        const SizedBox(width: 4),
                                        Text(
                                          cl.nombre,
                                          style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  }

                  return const SizedBox.shrink();
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Selectores: Canal de Venta y Método de Pago (Con isExpanded: true y elisión para evitar desbordes)
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<CanalVenta>(
                  initialValue: cart.canal,
                  isExpanded: true,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Canal',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: CanalVenta.values.map((c) {
                    return DropdownMenuItem(
                      value: c,
                      child: Text(
                        c.label,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) ref.read(posCartProvider.notifier).setCanal(v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<MetodoPago>(
                  initialValue: cart.metodoPago,
                  isExpanded: true,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Método Pago',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: MetodoPago.values.map((m) {
                    return DropdownMenuItem(
                      value: m,
                      child: Text(
                        m.label,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) ref.read(posCartProvider.notifier).setMetodoPago(v);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: AppTheme.borderLight, height: 1),

          // Lista de ítems en carrito
          Expanded(
            child: cart.items.isEmpty
                ? const Center(
                    child: Text(
                      'No hay productos seleccionados.\nToca un producto para agregar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: cart.items.length,
                    separatorBuilder: (_, _) => const Divider(color: AppTheme.borderLight, height: 1),
                    itemBuilder: (context, idx) {
                      final it = cart.items[idx];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          it.presentacion.nombre,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${it.cantidad} x ${Formatters.currency(it.presentacion.precioVigente)}',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              Formatters.currency(it.subtotal),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryAmber,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16, color: AppTheme.errorCoral),
                              onPressed: () {
                                ref.read(posCartProvider.notifier).eliminarItem(it.presentacion.id);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          const Divider(color: AppTheme.borderLight, height: 1),
          const SizedBox(height: 8),

          // Totales y Cobro
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal:', style: TextStyle(color: AppTheme.textSecondary)),
                  Text(Formatters.currency(cart.subtotal), style: const TextStyle(color: AppTheme.textPrimary)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Descuento:', style: TextStyle(color: AppTheme.textSecondary)),
                  Text('- ${Formatters.currency(cart.descuento)}', style: const TextStyle(color: AppTheme.errorCoral)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL A COBRAR:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    Formatters.currency(cart.total),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryAmber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: cart.items.isEmpty || cart.isLoading ? null : _procesarVenta,
                  icon: cart.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.flash_on, color: Colors.black),
                  label: Text(
                    cart.isLoading ? 'DESPACHANDO...' : 'DESPACHAR Y REGISTRAR',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Diálogo modal interactivo para buscar clientes registrados con compras previas
class _DialogoBuscarCliente extends ConsumerStatefulWidget {
  final Function(ClienteHistorial cliente) onClienteSeleccionado;

  const _DialogoBuscarCliente({
    required this.onClienteSeleccionado,
  });

  @override
  ConsumerState<_DialogoBuscarCliente> createState() => _DialogoBuscarClienteState();
}

class _DialogoBuscarClienteState extends ConsumerState<_DialogoBuscarCliente> {
  final TextEditingController _dialogSearchCtrl = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _dialogSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientesAsync = ref.watch(clientesRegistradosProvider);

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 580),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera del diálogo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryAmber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.person_search_rounded, color: AppTheme.primaryAmber, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Buscar Cliente Registrado',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Historial de clientes con compras previas en barra',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Campo de búsqueda en vivo
              TextField(
                controller: _dialogSearchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre de cliente o ticket...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.secondaryCyan),
                  suffixIcon: _dialogSearchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _dialogSearchCtrl.clear();
                            setState(() => _filter = '');
                          },
                        )
                      : null,
                ),
                onChanged: (val) {
                  setState(() => _filter = val.trim().toLowerCase());
                },
              ),
              const SizedBox(height: 14),

              // Lista de Clientes con compras registradas
              Expanded(
                child: clientesAsync.when(
                  data: (clientes) {
                    final filtrados = clientes.where((c) {
                      if (_filter.isEmpty) return true;
                      final matchNombre = c.nombre.toLowerCase().contains(_filter);
                      final matchTicket = c.ultimoTicket?.toLowerCase().contains(_filter) ?? false;
                      return matchNombre || matchTicket;
                    }).toList();

                    if (filtrados.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_search, size: 48, color: AppTheme.textMuted),
                              const SizedBox(height: 12),
                              Text(
                                _filter.isEmpty
                                    ? 'No hay clientes registrados con compras previas'
                                    : 'No se encontraron clientes registrados con "$_filter"',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              ),
                              if (_filter.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    final nuevoNombre = _dialogSearchCtrl.text.trim();
                                    widget.onClienteSeleccionado(ClienteHistorial(
                                      nombre: nuevoNombre,
                                      totalCompras: 0,
                                    ));
                                    Navigator.pop(context);
                                  },
                                  icon: const Icon(Icons.person_add, size: 16, color: Colors.black),
                                  label: Text(
                                    'Usar "$_filter" como nuevo cliente',
                                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: filtrados.length,
                      separatorBuilder: (_, _) => const Divider(color: AppTheme.borderLight, height: 1),
                      itemBuilder: (context, idx) {
                        final item = filtrados[idx];
                        final initial = item.nombre.isNotEmpty ? item.nombre[0].toUpperCase() : 'C';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.surfaceVariant,
                            foregroundColor: AppTheme.primaryAmber,
                            radius: 20,
                            child: Text(
                              initial,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.nombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppTheme.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryAmber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${item.totalCompras} ${item.totalCompras == 1 ? 'compra' : 'compras'}',
                                  style: const TextStyle(
                                    color: AppTheme.primaryAmber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                if (item.ultimoTicket != null) ...[
                                  Text(
                                    item.ultimoTicket!,
                                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (item.ultimaCompra != null) ...[
                                  Text(
                                    '• Última: ${Formatters.date(item.ultimaCompra!)}',
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  '• ${Formatters.currency(item.totalGastado)}',
                                  style: const TextStyle(color: AppTheme.successMint, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              backgroundColor: AppTheme.surfaceVariant,
                              foregroundColor: AppTheme.secondaryCyan,
                              elevation: 0,
                              side: const BorderSide(color: AppTheme.secondaryCyan),
                            ),
                            onPressed: () {
                              widget.onClienteSeleccionado(item);
                              Navigator.pop(context);
                            },
                            child: const Text('Seleccionar', style: TextStyle(fontSize: 12)),
                          ),
                          onTap: () {
                            widget.onClienteSeleccionado(item);
                            Navigator.pop(context);
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryAmber),
                  ),
                  error: (err, _) => Center(
                    child: Text(
                      'Error al consultar clientes: $err',
                      style: const TextStyle(color: AppTheme.errorCoral),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
