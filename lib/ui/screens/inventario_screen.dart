import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/insumo_model.dart';
import '../../models/movimiento_kardex_model.dart';
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

  /// Modal para registrar cualquier movimiento de inventario (Entrada, Merma, Traslado)
  void _mostrarDialogoRegistrarMovimiento({
    required BuildContext context,
    Insumo? insumoPreseleccionado,
    List<Insumo> listaInsumos = const [],
  }) {
    Insumo? insumoActual = insumoPreseleccionado ?? (listaInsumos.isNotEmpty ? listaInsumos.first : null);
    TipoMovimientoKardex tipoSeleccionado = TipoMovimientoKardex.entrada;
    final cantCtrl = TextEditingController();
    final notaCtrl = TextEditingController();
    String motivoMerma = 'Rotura de botella';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final String unidad = insumoActual?.unidadMedida ?? 'unidad';

          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.swap_horiz_rounded, color: AppTheme.primaryAmber, size: 22),
                ),
                const SizedBox(width: 10),
                const Text('Registrar Movimiento Kardex', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selector de Insumo
                  const Text('Insumo Físico:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  if (insumoPreseleccionado != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Text(
                        '${insumoPreseleccionado.nombre} (Stock: ${Formatters.number(insumoPreseleccionado.stockActual)} ${insumoPreseleccionado.unidadMedida})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    )
                  else
                    DropdownButtonFormField<Insumo>(
                      key: ValueKey(insumoActual?.id),
                      initialValue: insumoActual,
                      isExpanded: true,
                      dropdownColor: AppTheme.surface,
                      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(10)),
                      items: listaInsumos.map((i) {
                        return DropdownMenuItem(
                          value: i,
                          child: Text(
                            '${i.nombre} (${Formatters.number(i.stockActual)} ${i.unidadMedida})',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => insumoActual = val);
                      },
                    ),

                  const SizedBox(height: 16),

                  // Selector de Tipo de Movimiento
                  const Text('Tipo de Operación:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  RadioGroup<TipoMovimientoKardex>(
                    groupValue: tipoSeleccionado,
                    onChanged: (v) {
                      if (v != null) setModalState(() => tipoSeleccionado = v);
                    },
                    child: Column(
                      children: const [
                        RadioListTile<TipoMovimientoKardex>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppTheme.successMint,
                          title: Text('Recepción de Insumos (+ Suma Stock)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: Text('Entrada por compra o reposición de bodega', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                          value: TipoMovimientoKardex.entrada,
                        ),
                        RadioListTile<TipoMovimientoKardex>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppTheme.errorCoral,
                          title: Text('Registro de Merma (- Resta Stock)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: Text('Pérdida por rotura, derrame o vencimiento', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                          value: TipoMovimientoKardex.merma,
                        ),
                        RadioListTile<TipoMovimientoKardex>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppTheme.infoViolet,
                          title: Text('Traslado a Sede 2 (- Resta Stock)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: Text('Transferencia con destino fijo: Sede 2', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                          value: TipoMovimientoKardex.traspasoSede2,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Campo de Cantidad
                  TextField(
                    controller: cantCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Cantidad a mover ($unidad) *',
                      prefixIcon: const Icon(Icons.numbers),
                      isDense: true,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Campo específico si es Merma
                  if (tipoSeleccionado == TipoMovimientoKardex.merma) ...[
                    DropdownButtonFormField<String>(
                      key: ValueKey(motivoMerma),
                      initialValue: motivoMerma,
                      isExpanded: true,
                      dropdownColor: AppTheme.surface,
                      decoration: const InputDecoration(labelText: 'Motivo de la merma *', isDense: true),
                      items: const [
                        DropdownMenuItem(value: 'Rotura de botella', child: Text('Rotura de botella')),
                        DropdownMenuItem(value: 'Derrame en preparación', child: Text('Derrame en preparación')),
                        DropdownMenuItem(value: 'Vencimiento / Descomposición', child: Text('Vencimiento / Descomposición')),
                        DropdownMenuItem(value: 'Ajuste de inventario negativo', child: Text('Ajuste de inventario negativo')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => motivoMerma = val);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Campo de notas / detalle
                  TextField(
                    controller: notaCtrl,
                    decoration: InputDecoration(
                      labelText: tipoSeleccionado == TipoMovimientoKardex.traspasoSede2
                          ? 'Responsable / Nota de entrega (Destino: Sede 2)'
                          : 'Nota u observación (opcional)',
                      prefixIcon: const Icon(Icons.comment_outlined),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: tipoSeleccionado == TipoMovimientoKardex.entrada
                      ? AppTheme.successMint
                      : (tipoSeleccionado == TipoMovimientoKardex.merma ? AppTheme.errorCoral : AppTheme.infoViolet),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final double? cant = double.tryParse(cantCtrl.text.replaceAll(',', '.'));
                  if (cant == null || cant <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ingrese una cantidad válida mayor a 0'), backgroundColor: AppTheme.errorCoral),
                    );
                    return;
                  }

                  if (insumoActual == null) return;

                  final service = ref.read(insumosServiceProvider);
                  String motivoFinal;
                  if (tipoSeleccionado == TipoMovimientoKardex.merma) {
                    motivoFinal = '$motivoMerma${notaCtrl.text.isNotEmpty ? ' - ${notaCtrl.text}' : ''}';
                  } else if (tipoSeleccionado == TipoMovimientoKardex.traspasoSede2) {
                    motivoFinal = 'Traslado a Sede 2${notaCtrl.text.isNotEmpty ? ': ${notaCtrl.text}' : ''}';
                  } else {
                    motivoFinal = notaCtrl.text.isNotEmpty ? notaCtrl.text : 'Recepción de Insumos';
                  }

                  await service.registrarMovimiento(
                    insumoId: insumoActual!.id,
                    tipo: tipoSeleccionado,
                    cantidad: cant,
                    motivo: motivoFinal,
                    destino: tipoSeleccionado == TipoMovimientoKardex.traspasoSede2 ? 'Sede 2' : 'Barra Principal',
                  );

                  ref.invalidate(listaInsumosProvider);
                  ref.invalidate(inventarioProductosProvider);

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Movimiento registrado con éxito para ${insumoActual!.nombre}'),
                        backgroundColor: AppTheme.successMint,
                      ),
                    );
                  }
                },
                child: const Text('Confirmar Movimiento'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Acción rápida para marcar insumo como agotado
  void _confirmarMarcarAgotado(BuildContext context, Insumo insumo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppTheme.errorCoral, size: 28),
            SizedBox(width: 8),
            Text('¿Marcar como AGOTADO?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              insumo.nombre,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Stock actual: ${Formatters.number(insumo.stockActual)} ${insumo.unidadMedida}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              'Al confirmar, el stock físico se establecerá en 0.00, se activará la etiqueta roja de AGOTADO y se registrará automáticamente en movimientos_kardex.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
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
              backgroundColor: AppTheme.errorCoral,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await ref.read(insumosServiceProvider).marcarAgotado(insumoId: insumo.id);
              ref.invalidate(listaInsumosProvider);
              ref.invalidate(inventarioProductosProvider);

              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('¡${insumo.nombre} ha sido marcado como AGOTADO!'),
                    backgroundColor: AppTheme.errorCoral,
                  ),
                );
              }
            },
            child: const Text('Sí, Marcar Agotado'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final insumosAsync = ref.watch(listaInsumosProvider);
    final filtroUnidad = ref.watch(insumosFiltroUnidadProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryAmber,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text(
          '+ Registrar Movimiento',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        onPressed: () {
          final items = insumosAsync.asData?.value ?? [];
          _mostrarDialogoRegistrarMovimiento(context: context, listaInsumos: items);
        },
      ),
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
                                    ref.read(insumosBusquedaProvider.notifier).state = '';
                                  },
                                )
                              : null,
                        ),
                        onChanged: (val) {
                          ref.read(insumosBusquedaProvider.notifier).state = val;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppTheme.primaryAmber),
                      tooltip: 'Actualizar inventario',
                      onPressed: () => ref.invalidate(listaInsumosProvider),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(filtroUnidad),
                  initialValue: filtroUnidad ?? 'TODOS',
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
                    prefixIcon: const Icon(Icons.straighten_rounded, color: AppTheme.primaryAmber, size: 20),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'TODOS', child: Text('Todas las unidades de medida')),
                    DropdownMenuItem(value: 'ml', child: Text('Líquidos & Licores (ml)')),
                    DropdownMenuItem(value: 'unidad', child: Text('Botellas & Unidades (unidad)')),
                    DropdownMenuItem(value: 'gr', child: Text('Sólidos & Frutas (gr)')),
                  ],
                  onChanged: (val) {
                    ref.read(insumosFiltroUnidadProvider.notifier).state = (val == null || val == 'TODOS') ? null : val;
                  },
                ),
              ],
            ),
          ),

          // Lista de Insumos Físicos Kardex
          Expanded(
            child: insumosAsync.when(
              data: (insumos) {
                if (insumos.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay insumos registrados en inventario',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: insumos.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final insumo = insumos[idx];
                    final bool agotado = insumo.estaAgotado;
                    final bool bajoMinimo = insumo.requiereReabastecimiento;

                    Color estadoColor;
                    String estadoTexto;
                    IconData estadoIcon;

                    if (agotado) {
                      estadoColor = AppTheme.errorCoral;
                      estadoTexto = 'AGOTADO';
                      estadoIcon = Icons.do_not_disturb_on_rounded;
                    } else if (bajoMinimo) {
                      estadoColor = Colors.orange;
                      estadoTexto = 'BAJO MÍNIMO';
                      estadoIcon = Icons.warning_amber_rounded;
                    } else {
                      estadoColor = AppTheme.successMint;
                      estadoTexto = 'ÓPTIMO';
                      estadoIcon = Icons.check_circle_outline;
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // FILA 1: Ícono + Nombre completo en Expanded + Menú de 3 puntos
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: estadoColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(estadoIcon, color: estadoColor, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    insumo.nombre,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, color: AppTheme.textMuted, size: 20),
                                  color: AppTheme.surface,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  onSelected: (val) {
                                    if (val == 'mover') {
                                      _mostrarDialogoRegistrarMovimiento(
                                        context: context,
                                        insumoPreseleccionado: insumo,
                                        listaInsumos: insumos,
                                      );
                                    } else if (val == 'agotado') {
                                      _confirmarMarcarAgotado(context, insumo);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'mover',
                                      child: Row(
                                        children: [
                                          Icon(Icons.swap_horiz, size: 18, color: AppTheme.primaryAmber),
                                          SizedBox(width: 8),
                                          Text('Mover / Merma', style: TextStyle(fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    if (!agotado)
                                      const PopupMenuItem(
                                        value: 'agotado',
                                        child: Row(
                                          children: [
                                            Icon(Icons.do_not_disturb_on_rounded, size: 18, color: AppTheme.errorCoral),
                                            SizedBox(width: 8),
                                            Text('Marcar Agotado', style: TextStyle(fontSize: 13, color: AppTheme.errorCoral)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // FILA 2: Categoría/unidad a la izquierda + Stock actual y mínimo a la derecha
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: estadoColor.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: estadoColor.withValues(alpha: 0.5)),
                                            ),
                                            child: Text(
                                              estadoTexto,
                                              style: TextStyle(
                                                color: estadoColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Unidad: ${insumo.unidadMedida}',
                                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Mínimo: ${Formatters.number(insumo.stockMinimo)} ${insumo.unidadMedida}',
                                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${Formatters.number(insumo.stockActual)} ${insumo.unidadMedida}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: agotado ? AppTheme.errorCoral : AppTheme.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Mín: ${Formatters.number(insumo.stockMinimo)}',
                                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // Barra de nivel de stock
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: insumo.porcentajeStock / 2.0,
                                minHeight: 5,
                                backgroundColor: AppTheme.surfaceVariant,
                                valueColor: AlwaysStoppedAnimation<Color>(estadoColor),
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Fila de Acciones Rápidas
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.errorCoral,
                                    side: BorderSide(
                                      color: agotado ? AppTheme.textMuted : AppTheme.errorCoral.withValues(alpha: 0.6),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: agotado
                                      ? null
                                      : () => _confirmarMarcarAgotado(context, insumo),
                                  icon: const Icon(Icons.do_not_disturb_on_rounded, size: 15),
                                  label: Text(agotado ? 'Agotado' : 'Marcar Agotado', style: const TextStyle(fontSize: 11)),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: AppTheme.primaryAmber,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  ),
                                  icon: const Icon(Icons.swap_horiz, size: 16),
                                  label: const Text('Mover / Merma', style: TextStyle(fontSize: 11)),
                                  onPressed: () {
                                    _mostrarDialogoRegistrarMovimiento(
                                      context: context,
                                      insumoPreseleccionado: insumo,
                                      listaInsumos: insumos,
                                    );
                                  },
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
                child: Text('Error al cargar insumos: $err', style: const TextStyle(color: AppTheme.errorCoral)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
