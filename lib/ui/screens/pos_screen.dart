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
import '../../services/comandas_service.dart';
import '../widgets/product_card.dart';
import '../widgets/resumen_turno_modal.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  late final TextEditingController _clienteCtrl;
  late final TextEditingController _cedulaCtrl;
  late final TextEditingController _ticketCajaCtrl;
  final TextEditingController _buscarClienteBarCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final cart = ref.read(posCartProvider);
    _clienteCtrl = TextEditingController(text: cart.clienteNombre);
    _cedulaCtrl = TextEditingController(text: cart.clienteCedula);
    _ticketCajaCtrl = TextEditingController(text: cart.numeroTicketCaja);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _clienteCtrl.dispose();
    _cedulaCtrl.dispose();
    _ticketCajaCtrl.dispose();
    _buscarClienteBarCtrl.dispose();
    super.dispose();
  }

  void _seleccionarCliente(ClienteHistorial cliente) {
    _clienteCtrl.text = cliente.nombre;
    _cedulaCtrl.text = cliente.cedula ?? '';
    _buscarClienteBarCtrl.clear();
    ref.read(posCartProvider.notifier).setCliente(
          nombre: cliente.nombre,
          cedula: cliente.cedula,
        );
    setState(() {});
  }

  void _limpiarCliente() {
    _clienteCtrl.clear();
    _cedulaCtrl.clear();
    _ticketCajaCtrl.clear();
    _buscarClienteBarCtrl.clear();
    ref.read(posCartProvider.notifier).setCliente(nombre: '', cedula: '');
    ref.read(posCartProvider.notifier).setNumeroTicketCaja('');
    setState(() {});
  }

  void _mostrarDialogoBuscarCliente(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _DialogoBuscarCliente(
        onClienteSeleccionado: (cliente) {
          _seleccionarCliente(cliente);
        },
      ),
    );
  }

  void _abrirComanda(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.90,
            child: _buildComandaSidebar(context),
          );
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
        clienteCedula: cart.clienteCedula.isNotEmpty ? cart.clienteCedula : null,
        notas: cart.notas.isNotEmpty ? cart.notas : null,
        descuento: cart.descuento,
      );

      // Sincronizar con el módulo de Comandas e Insumos (con recetas y descuento automático)
      final String ticketFinal = cart.numeroTicketCaja.trim().isNotEmpty
          ? cart.numeroTicketCaja.trim()
          : movimiento.numeroTicket;

      try {
        final comandaItems = cart.items.map((it) {
          String prodId = it.presentacion.id;
          if (it.presentacion.equivalencias.isNotEmpty &&
              it.presentacion.equivalencias.first.productoId.isNotEmpty) {
            prodId = it.presentacion.equivalencias.first.productoId;
          }

          String cat = 'Otros';
          final catName = it.presentacion.categoria.name.toLowerCase();
          if (catName.contains('coctel')) {
            cat = 'Cocteles';
          } else if (catName.contains('jugo') || catName.contains('noalcohol')) {
            cat = 'Jugos';
          } else if (catName.contains('cerv')) {
            cat = 'Cervezas';
          }

          return DetalleComandaInput(
            productoId: prodId,
            categoria: cat,
            cantidad: it.cantidad.toDouble(),
            precioUnitario: it.presentacion.precioVigente,
          );
        }).toList();

        await ref.read(comandasServiceProvider).registrarComanda(
          numeroTicketCaja: ticketFinal,
          items: comandaItems,
          clienteNombre: cart.clienteNombre.isNotEmpty ? cart.clienteNombre : null,
          notas: cart.notas.isNotEmpty ? cart.notas : null,
        );
      } catch (comandaErr) {
        debugPrint('Aviso al sincronizar comanda e insumos: $comandaErr');
      }

      ref.read(posCartProvider.notifier).limpiarCarrito();
      _limpiarCliente();
      ref.invalidate(inventarioProductosProvider);
      ref.invalidate(ultimasVentasProvider);
      ref.invalidate(clientesRegistradosProvider);
      ref.invalidate(listaInsumosProvider);
      ref.invalidate(resumenTurnoProvider);

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
                  padding: const EdgeInsets.only(bottom: 4),
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
              if (movimiento.clienteCedula != null && movimiento.clienteCedula!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.badge_outlined, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'Cédula / ID: ${movimiento.clienteCedula}',
                        style: const TextStyle(color: AppTheme.textSecondary),
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

    // Sincronizar controladores si el estado del carrito se limpia externamente
    ref.listen<String>(
      posCartProvider.select((s) => s.clienteNombre),
      (prev, next) {
        if (_clienteCtrl.text != next) {
          _clienteCtrl.text = next;
        }
      },
    );
    ref.listen<String>(
      posCartProvider.select((s) => s.clienteCedula),
      (prev, next) {
        if (_cedulaCtrl.text != next) {
          _cedulaCtrl.text = next;
        }
      },
    );
    ref.listen<String>(
      posCartProvider.select((s) => s.numeroTicketCaja),
      (prev, next) {
        if (_ticketCajaCtrl.text != next) {
          _ticketCajaCtrl.text = next;
        }
      },
    );

    return Scaffold(
      body: Row(
        children: [
          // Sección Izquierda: Catálogo de Productos y Filtros
          Expanded(
            child: Column(
              children: [
                // Barra Superior: Búsqueda y Filtros de Categoría con Wrap (sin desbordes)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppTheme.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.summarize_outlined, color: AppTheme.secondaryCyan),
                            tooltip: 'Resumen de Turno (Reporte / PDF / Excel)',
                            onPressed: () => ResumenTurnoModal.show(context),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: AppTheme.primaryAmber),
                            tooltip: 'Actualizar catálogo',
                            onPressed: () => ref.invalidate(catalogoVentasProvider),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Filtro de Categoría Dropdown y Acceso a Comanda con Badge
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: ValueKey(categoriaFiltro),
                              initialValue: categoriaFiltro?.name ?? 'TODOS',
                              isExpanded: true,
                              dropdownColor: AppTheme.surface,
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                filled: true,
                                fillColor: AppTheme.surfaceVariant,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppTheme.borderLight),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppTheme.borderLight),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppTheme.primaryAmber),
                                ),
                                prefixIcon: const Icon(Icons.category_outlined, color: AppTheme.primaryAmber, size: 20),
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: 'TODOS',
                                  child: Text('Todas las categorías', overflow: TextOverflow.ellipsis),
                                ),
                                ...CategoriaProducto.values.map(
                                  (cat) => DropdownMenuItem<String>(
                                    value: cat.name,
                                    child: Text(cat.label, overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                if (val == null || val == 'TODOS') {
                                  ref.read(catalogoFiltroCategoriaProvider.notifier).state = null;
                                } else {
                                  ref.read(catalogoFiltroCategoriaProvider.notifier).state =
                                      CategoriaProducto.values.firstWhere((c) => c.name == val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Badge(
                            isLabelVisible: cart.totalUnidades > 0,
                            label: Text(
                              '${cart.totalUnidades}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: AppTheme.primaryAmber,
                            textColor: Colors.black,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryAmber,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _abrirComanda(context),
                              icon: const Icon(Icons.receipt_long, size: 20, color: Colors.black),
                              label: const Text(
                                'Comanda',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
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
              width: 420,
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(left: BorderSide(color: AppTheme.borderLight)),
              ),
              child: _buildComandaSidebar(context),
            ),
        ],
      ),
      bottomNavigationBar: !isDesktop && cart.items.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(12),
              color: AppTheme.surface,
              child: ElevatedButton(
                onPressed: () => _abrirComanda(context),
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

  Widget _buildComandaSidebar(BuildContext context) {
    final cart = ref.watch(posCartProvider);
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
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, color: AppTheme.primaryAmber),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Comanda de Barra',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
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
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.summarize_outlined, color: AppTheme.secondaryCyan, size: 20),
                    tooltip: 'Resumen de Turno (Reporte / PDF / Excel)',
                    onPressed: () => ResumenTurnoModal.show(context),
                  ),
                  if (cart.items.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        ref.read(posCartProvider.notifier).limpiarCarrito();
                        _limpiarCliente();
                      },
                      child: const Text('Limpiar', style: TextStyle(color: AppTheme.errorCoral)),
                    ),
                  if (MediaQuery.of(context).size.width < 900)
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                      tooltip: 'Cerrar comanda',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // SECCIÓN: DATOS DEL CLIENTE Y BUSCADOR POR NOMBRE O CÉDULA
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera del widget de cliente
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.badge_outlined, size: 16, color: AppTheme.primaryAmber),
                        SizedBox(width: 6),
                        Text(
                          'Datos del Cliente',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    if (cart.clienteNombre.isNotEmpty || cart.clienteCedula.isNotEmpty)
                      InkWell(
                        onTap: _limpiarCliente,
                        child: const Text(
                          'Limpiar',
                          style: TextStyle(fontSize: 11, color: AppTheme.errorCoral),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // 1. Barra de Búsqueda Interactiva por Nombre o Cédula
                TextField(
                  controller: _buscarClienteBarCtrl,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    hintText: 'Buscar cliente por Nombre o Cédula (V-...)...',
                    hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    prefixIcon: const Icon(Icons.person_search_rounded, color: AppTheme.secondaryCyan, size: 18),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_buscarClienteBarCtrl.text.isNotEmpty)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.clear, size: 16, color: AppTheme.textMuted),
                            onPressed: () {
                              _buscarClienteBarCtrl.clear();
                              setState(() {});
                            },
                          ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.manage_search_rounded, color: AppTheme.primaryAmber, size: 20),
                          tooltip: 'Abrir directorio de clientes',
                          onPressed: () => _mostrarDialogoBuscarCliente(context),
                        ),
                      ],
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {});
                  },
                ),

                // Lista desplegable de sugerencias de clientes cuando se escribe en el buscador
                if (_buscarClienteBarCtrl.text.trim().isNotEmpty)
                  clientesAsync.maybeWhen(
                    data: (clientes) {
                      final query = _buscarClienteBarCtrl.text.trim().toLowerCase();
                      final sugerencias = clientes.where((c) {
                        final nMatch = c.nombre.toLowerCase().contains(query);
                        final cMatch = c.cedula?.toLowerCase().contains(query) ?? false;
                        return nMatch || cMatch;
                      }).take(4).toList();

                      if (sugerencias.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 13, color: AppTheme.textMuted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Sin coincidencias previas. Ingrese los datos abajo.',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Column(
                          children: sugerencias.map((cl) {
                            return InkWell(
                              onTap: () => _seleccionarCliente(cl),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                child: Row(
                                  children: [
                                    const Icon(Icons.person, size: 14, color: AppTheme.secondaryCyan),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        cl.nombre,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (cl.cedula != null && cl.cedula!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: Text(
                                          cl.cedula!,
                                          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                        ),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryAmber.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${cl.totalCompras} comp.',
                                        style: const TextStyle(fontSize: 9, color: AppTheme.primaryAmber, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),

                const SizedBox(height: 8),

                // 2. Campos de Nombre de Cliente y Cédula
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _clienteCtrl,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Nombre del Cliente',
                          hintText: 'Ej. Carlos Mendoza...',
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          prefixIcon: Icon(Icons.person_outline, size: 16, color: AppTheme.primaryAmber),
                        ),
                        onChanged: (val) {
                          ref.read(posCartProvider.notifier).setClienteNombre(val);
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _cedulaCtrl,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Cédula / RIF',
                          hintText: 'V-18452123',
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          prefixIcon: Icon(Icons.credit_card, size: 16, color: AppTheme.secondaryCyan),
                        ),
                        onChanged: (val) {
                          ref.read(posCartProvider.notifier).setClienteCedula(val);
                        },
                      ),
                    ),
                  ],
                ),

                // 3. Insignia si coincide con cliente registrado o chips de acceso rápido
                clientesAsync.maybeWhen(
                  data: (clientes) {
                    if (clientes.isEmpty) return const SizedBox.shrink();

                    final match = clientes.cast<ClienteHistorial?>().firstWhere(
                          (c) =>
                              (cart.clienteNombre.isNotEmpty &&
                                  c?.nombre.trim().toLowerCase() == cart.clienteNombre.trim().toLowerCase()) ||
                              (cart.clienteCedula.isNotEmpty &&
                                  c?.cedula?.trim().toLowerCase() == cart.clienteCedula.trim().toLowerCase()),
                          orElse: () => null,
                        );

                    if (match != null && cart.clienteNombre.isNotEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_rounded, size: 14, color: AppTheme.successMint),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Cliente registrado: ${match.totalCompras} ${match.totalCompras == 1 ? 'compra previa' : 'compras previas'}${match.cedula != null ? ' • C.I: ${match.cedula}' : ''}',
                                style: const TextStyle(color: AppTheme.successMint, fontSize: 10, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (cart.clienteNombre.isEmpty && cart.clienteCedula.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              const Text(
                                'Frecuentes: ',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
                              ),
                              ...clientes.take(3).map((cl) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () => _seleccionarCliente(cl),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surface,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppTheme.borderLight),
                                      ),
                                      child: Text(
                                        '${cl.nombre}${cl.cedula != null ? ' (${cl.cedula})' : ''}',
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 10,
                                        ),
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
          ),
          const SizedBox(height: 8),

          // Campo: N° Ticket de Caja
          TextField(
            controller: _ticketCajaCtrl,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              labelText: 'N° Ticket de Caja',
              hintText: 'Ej. TC-0042 o #8492...',
              hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.confirmation_number_outlined, size: 18, color: AppTheme.primaryAmber),
              suffixIcon: _ticketCajaCtrl.text.isNotEmpty
                  ? IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.clear, size: 16, color: AppTheme.textMuted),
                      onPressed: () {
                        _ticketCajaCtrl.clear();
                        ref.read(posCartProvider.notifier).setNumeroTicketCaja('');
                        setState(() {});
                      },
                    )
                  : null,
            ),
            onChanged: (val) {
              ref.read(posCartProvider.notifier).setNumeroTicketCaja(val.trim());
              setState(() {});
            },
          ),
          const SizedBox(height: 8),

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

          const SizedBox(height: 10),

          // Buscador rápido de productos para agregar directamente a la comanda
          const _BuscadorProductoComanda(),

          const SizedBox(height: 10),
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
                            const SizedBox(width: 4),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.close, size: 18, color: AppTheme.errorCoral),
                              tooltip: 'Eliminar producto de comanda',
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
          const SizedBox(height: 6),

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
              const SizedBox(height: 10),

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

/// Diálogo modal interactivo para buscar clientes registrados con compras previas (por Nombre o Cédula)
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
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 600),
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
                            'Directorio de Clientes Registrados',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Búsqueda por Nombre o Número de Cédula / RIF',
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

              // Campo de búsqueda en vivo (Nombre o Cédula)
              TextField(
                controller: _dialogSearchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Escribe Nombre del cliente o Cédula (V-...)...',
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
                      final matchCedula = c.cedula?.toLowerCase().contains(_filter) ?? false;
                      final matchTicket = c.ultimoTicket?.toLowerCase().contains(_filter) ?? false;
                      return matchNombre || matchCedula || matchTicket;
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
                              if (item.cedula != null && item.cedula!.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryCyan.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.secondaryCyan.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    item.cedula!,
                                    style: const TextStyle(
                                      color: AppTheme.secondaryCyan,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
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

/// Buscador interactivo de productos dentro de la Comanda
class _BuscadorProductoComanda extends ConsumerStatefulWidget {
  const _BuscadorProductoComanda();

  @override
  ConsumerState<_BuscadorProductoComanda> createState() => _BuscadorProductoComandaState();
}

class _BuscadorProductoComandaState extends ConsumerState<_BuscadorProductoComanda> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogoCompletoAsync = ref.watch(catalogoCompletoVentasProvider);
    final catalogoVentasAsync = ref.watch(catalogoVentasProvider);
    final List<PresentacionVenta> catalogo =
        catalogoCompletoAsync.asData?.value ?? catalogoVentasAsync.asData?.value ?? [];

    final query = _searchCtrl.text.trim().toLowerCase();
    final sugerencias = query.isEmpty
        ? <PresentacionVenta>[]
        : catalogo
            .where((p) =>
                p.nombre.toLowerCase().contains(query) ||
                p.codigo.toLowerCase().contains(query))
            .take(6)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchCtrl,
          style: const TextStyle(fontSize: 12),
          onSubmitted: (_) {
            if (sugerencias.isNotEmpty) {
              ref.read(posCartProvider.notifier).agregarPresentacion(sugerencias.first);
              _searchCtrl.clear();
              setState(() {});
            }
          },
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Buscar y agregar producto a la comanda...',
            hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            prefixIcon: const Icon(
              Icons.add_shopping_cart_rounded,
              color: AppTheme.primaryAmber,
              size: 18,
            ),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.clear, size: 16, color: AppTheme.textMuted),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {});
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true,
            fillColor: AppTheme.surfaceVariant.withValues(alpha: 0.6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.primaryAmber),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (query.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: sugerencias.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: Center(
                      child: Text(
                        'No hay productos que coincidan',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: sugerencias.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: AppTheme.borderLight, height: 1),
                    itemBuilder: (context, index) {
                      final p = sugerencias[index];
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(
                          p.nombre,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${p.categoria.label} • ${Formatters.currency(p.precioVigente)}',
                          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                        ),
                        trailing: const Icon(
                          Icons.add_circle,
                          color: AppTheme.primaryAmber,
                          size: 20,
                        ),
                        onTap: () {
                          ref.read(posCartProvider.notifier).agregarPresentacion(p);
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }
}
