import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/producto_model.dart';
import '../../providers/app_providers.dart';

class InventarioScreen extends ConsumerStatefulWidget {
  const InventarioScreen({super.key});

  @override
  ConsumerState<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends ConsumerState<InventarioScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _mostrarDialogoSurtidoOMerma({
    required BuildContext context,
    required Producto producto,
    required bool esSurtido,
  }) {
    final cantCtrl = TextEditingController();
    final motivoCtrl = TextEditingController(
      text: esSurtido ? 'Reabastecimiento desde bodega' : 'Rotura de botella / merma en barra',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              esSurtido ? Icons.add_business_rounded : Icons.warning_amber_rounded,
              color: esSurtido ? AppTheme.successMint : AppTheme.errorCoral,
            ),
            const SizedBox(width: 8),
            Text(esSurtido ? 'Surtido de Barra' : 'Registrar Merma / Rotura'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              producto.nombre,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Stock actual: ${Formatters.number(producto.stockActual)} ${producto.unidadMedida}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: cantCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Cantidad (${producto.unidadMedida})',
                prefixIcon: const Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motivoCtrl,
              decoration: const InputDecoration(
                labelText: 'Motivo / Justificación',
                prefixIcon: Icon(Icons.comment),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: esSurtido ? AppTheme.successMint : AppTheme.errorCoral,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final double? cant = double.tryParse(cantCtrl.text.replaceAll(',', '.'));
              if (cant == null || cant <= 0) return;

              final service = ref.read(productosServiceProvider);
              if (esSurtido) {
                await service.registrarEntradaSurtido(
                  productoId: producto.id,
                  cantidad: cant,
                  motivo: motivoCtrl.text,
                );
              } else {
                await service.registrarMerma(
                  productoId: producto.id,
                  cantidad: cant,
                  motivo: motivoCtrl.text,
                );
              }

              ref.invalidate(inventarioProductosProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(esSurtido ? 'Ingresar Surtido' : 'Registrar Merma'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(inventarioProductosProvider);
    final categoriaFiltro = ref.watch(inventarioFiltroCategoriaProvider);

    return Scaffold(
      body: Column(
        children: [
          // Barra de Búsqueda y Filtros
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
                          hintText: 'Buscar insumo físico en barra...',
                          prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    ref.read(inventarioBusquedaProvider.notifier).state = '';
                                  },
                                )
                              : null,
                        ),
                        onChanged: (val) {
                          ref.read(inventarioBusquedaProvider.notifier).state = val;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppTheme.primaryAmber),
                      onPressed: () => ref.invalidate(inventarioProductosProvider),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Todos'),
                        selected: categoriaFiltro == null,
                        onSelected: (_) {
                          ref.read(inventarioFiltroCategoriaProvider.notifier).state = null;
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
                              ref.read(inventarioFiltroCategoriaProvider.notifier).state =
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
              ],
            ),
          ),

          // Lista de Insumos Físicos Kardex
          Expanded(
            child: productosAsync.when(
              data: (productos) {
                if (productos.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay productos registrados en inventario',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: productos.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final p = productos[idx];
                    final bool bajoMinimo = p.requiereReabastecimiento;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Icono de estado de stock
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: bajoMinimo
                                    ? AppTheme.errorCoral.withValues(alpha: 0.15)
                                    : AppTheme.successMint.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                bajoMinimo
                                    ? Icons.warning_amber_rounded
                                    : Icons.inventory_2_outlined,
                                color: bajoMinimo ? AppTheme.errorCoral : AppTheme.successMint,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Detalles del Producto
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        p.nombre,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      if (bajoMinimo) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.errorCoral.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'SURTIR',
                                            style: TextStyle(
                                              color: AppTheme.errorCoral,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Código: ${p.codigo} | Categoría: ${p.categoria.label}',
                                    style: const TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Barra de progreso de stock
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: p.porcentajeStock / 2.0,
                                      minHeight: 6,
                                      backgroundColor: AppTheme.surfaceVariant,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        bajoMinimo ? AppTheme.errorCoral : AppTheme.successMint,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Valores de Stock
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${Formatters.number(p.stockActual)} ${p.unidadMedida}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: bajoMinimo
                                        ? AppTheme.errorCoral
                                        : AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Mín: ${Formatters.number(p.stockMinimo)} ${p.unidadMedida}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),

                            // Acciones Rápidas
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
                              color: AppTheme.surfaceVariant,
                              onSelected: (val) {
                                if (val == 'surtido') {
                                  _mostrarDialogoSurtidoOMerma(
                                    context: context,
                                    producto: p,
                                    esSurtido: true,
                                  );
                                } else if (val == 'merma') {
                                  _mostrarDialogoSurtidoOMerma(
                                    context: context,
                                    producto: p,
                                    esSurtido: false,
                                  );
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'surtido',
                                  child: Row(
                                    children: [
                                      Icon(Icons.add_circle_outline, color: AppTheme.successMint, size: 18),
                                      SizedBox(width: 8),
                                      Text('Ingresar Surtido'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'merma',
                                  child: Row(
                                    children: [
                                      Icon(Icons.remove_circle_outline, color: AppTheme.errorCoral, size: 18),
                                      SizedBox(width: 8),
                                      Text('Registrar Merma/Rotura'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryAmber),
              ),
              error: (err, _) => Center(
                child: Text('Error: $err', style: const TextStyle(color: AppTheme.errorCoral)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
