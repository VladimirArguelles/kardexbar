import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/supabase_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/app_providers.dart';

class GestionCatalogoModal extends ConsumerStatefulWidget {
  final VoidCallback onDataChanged;

  const GestionCatalogoModal({super.key, required this.onDataChanged});

  static Future<void> show(BuildContext context, {required VoidCallback onDataChanged}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: GestionCatalogoModal(onDataChanged: onDataChanged),
      ),
    );
  }

  @override
  ConsumerState<GestionCatalogoModal> createState() => _GestionCatalogoModalState();
}

class _GestionCatalogoModalState extends ConsumerState<GestionCatalogoModal> {
  int _tabIndex = 0; // 0: Categorías, 1: Productos

  // Estados de Categorías
  final TextEditingController _nuevaCatCtrl = TextEditingController();
  bool _loadingCats = false;
  List<Map<String, dynamic>> _categorias = [];

  // Estados de Productos
  bool _loadingProds = false;
  List<Map<String, dynamic>> _productos = [];
  String _filtroCatProducto = 'TODOS';
  String _busquedaProducto = '';
  final TextEditingController _searchProdCtrl = TextEditingController();

  // Insumos disponibles en barra para asociar a recetas
  List<Map<String, dynamic>> _insumosDisponibles = [];

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
    _cargarProductos();
    _cargarInsumos();
  }

  @override
  void dispose() {
    _nuevaCatCtrl.dispose();
    _searchProdCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarCategorias() async {
    setState(() => _loadingCats = true);
    try {
      final res = await SupabaseConfig.client
          .from('categorias')
          .select()
          .order('nombre');
      if (mounted) {
        setState(() {
          _categorias = List<Map<String, dynamic>>.from(res as List);
          _loadingCats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCats = false);
    }
  }

  Future<void> _cargarInsumos() async {
    try {
      final res = await SupabaseConfig.client
          .from('insumos')
          .select('id, nombre, unidad_medida')
          .order('nombre');
      if (mounted) {
        setState(() {
          _insumosDisponibles = List<Map<String, dynamic>>.from(res as List);
        });
      }
    } catch (_) {}
  }

  Future<void> _cargarProductos() async {
    setState(() => _loadingProds = true);
    try {
      final res = await SupabaseConfig.client
          .from('productos')
          .select('*, recetas(*, insumos(nombre, unidad_medida))')
          .order('nombre');
      if (mounted) {
        setState(() {
          _productos = List<Map<String, dynamic>>.from(res as List);
          _loadingProds = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProds = false);
    }
  }

  // --- CRUD CATEGORÍAS ---
  Future<void> _crearCategoria() async {
    final nombre = _nuevaCatCtrl.text.trim();
    if (nombre.isEmpty) return;

    try {
      await SupabaseConfig.client.from('categorias').insert({'nombre': nombre});
      _nuevaCatCtrl.clear();
      await _cargarCategorias();
      widget.onDataChanged();
      ref.invalidate(categoriasDbListProvider);
      ref.invalidate(catalogoVentasProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear categoría: $e'), backgroundColor: AppTheme.errorCoral),
        );
      }
    }
  }

  Future<void> _editarCategoria(Map<String, dynamic> cat) async {
    final editCtrl = TextEditingController(text: cat['nombre']?.toString() ?? '');
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Editar Categoría', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: editCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre de la categoría', isDense: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAmber, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );

    if (confirmar == true && editCtrl.text.trim().isNotEmpty) {
      final nuevoNombre = editCtrl.text.trim();
      final anteriorNombre = cat['nombre'];
      try {
        await SupabaseConfig.client
            .from('categorias')
            .update({'nombre': nuevoNombre})
            .eq('id', cat['id']);

        // Propagar nombre a productos y presentaciones de venta
        await SupabaseConfig.client
            .from('productos')
            .update({'categoria': nuevoNombre})
            .eq('categoria', anteriorNombre);

        await SupabaseConfig.client
            .from('presentaciones_venta')
            .update({'categoria': nuevoNombre})
            .eq('categoria', anteriorNombre);

        await _cargarCategorias();
        await _cargarProductos();
        widget.onDataChanged();
        ref.invalidate(categoriasDbListProvider);
        ref.invalidate(catalogoVentasProvider);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al actualizar categoría: $e'), backgroundColor: AppTheme.errorCoral),
          );
        }
      }
    }
  }

  Future<void> _eliminarCategoria(Map<String, dynamic> cat) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar Categoría'),
        content: Text('¿Deseas eliminar la categoría "${cat['nombre']}" de la base de datos?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorCoral, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await SupabaseConfig.client
            .from('categorias')
            .delete()
            .eq('id', cat['id']);

        await _cargarCategorias();
        widget.onDataChanged();
        ref.invalidate(categoriasDbListProvider);
        ref.invalidate(catalogoVentasProvider);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar categoría: $e'), backgroundColor: AppTheme.errorCoral),
          );
        }
      }
    }
  }

  // --- EDITOR DE PRODUCTO (Nombre, Categoría, Precio, Ingredientes) ---
  Future<void> _abrirEditorProducto({Map<String, dynamic>? producto}) async {
    final isEditing = producto != null;
    final nombreCtrl = TextEditingController(text: producto != null ? producto['nombre']?.toString() : '');
    final precioCtrl = TextEditingController(
      text: producto != null ? (producto['precio'] as num?)?.toStringAsFixed(2) ?? '0.00' : '0.00',
    );
    String catSeleccionada = producto != null && producto['categoria'] != null
        ? producto['categoria'].toString()
        : (_categorias.isNotEmpty ? _categorias.first['nombre'].toString() : 'Otros');

    // Lista temporal de ingredientes de la receta
    List<Map<String, dynamic>> recetaItems = [];
    if (producto != null && producto['recetas'] is List) {
      for (final r in producto['recetas']) {
        recetaItems.add({
          'insumo_id': r['insumo_id'],
          'insumo_nombre': r['insumos'] != null ? r['insumos']['nombre'] : 'Insumo',
          'unidad_medida': r['insumos'] != null ? r['insumos']['unidad_medida'] : 'ml',
          'cantidad_descuento': (r['cantidad_descuento'] as num?)?.toDouble() ?? 10.0,
        });
      }
    }

    String? nuevoInsumoId = _insumosDisponibles.isNotEmpty ? _insumosDisponibles.first['id']?.toString() : null;
    final cantInsumoCtrl = TextEditingController(text: '30');

    final bool? guardado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setEditorState) {
          return Dialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(isEditing ? Icons.edit_note_rounded : Icons.add_circle_outline, color: AppTheme.primaryAmber, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              isEditing ? 'Editar Producto & Receta' : 'Nuevo Producto & Receta',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(dialogCtx, false),
                        ),
                      ],
                    ),
                    const Divider(color: AppTheme.borderLight, height: 20),

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Nombre
                            TextField(
                              controller: nombreCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nombre del Producto *',
                                hintText: 'Ej. Mojito Cubano, Cerveza Zulia...',
                                isDense: true,
                                prefixIcon: Icon(Icons.liquor_outlined, size: 18),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 2. Fila Categoría y Precio
                            Row(
                              children: [
                                // Categoría
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: catSeleccionada,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Categoría *',
                                      isDense: true,
                                      prefixIcon: Icon(Icons.category_outlined, size: 18),
                                    ),
                                    items: _categorias.map((c) {
                                      final n = c['nombre'].toString();
                                      return DropdownMenuItem(value: n, child: Text(n, overflow: TextOverflow.ellipsis));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setEditorState(() => catSeleccionada = val);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Precio
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: precioCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Precio (\$ USD) *',
                                      prefixIcon: Icon(Icons.attach_money, size: 18),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // 3. SECCIÓN INGREDIENTES / RECETA
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.borderLight),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.inventory_2_outlined, size: 16, color: AppTheme.secondaryCyan),
                                      SizedBox(width: 6),
                                      Text(
                                        'Ingredientes / Descuento de Insumos Físicos',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Al registrar una comanda de este producto, Supabase descontará automáticamente estas cantidades en Kardex.',
                                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                  const SizedBox(height: 12),

                                  // Lista de ingredientes añadidos
                                  if (recetaItems.isEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surface,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'Sin ingredientes asociados (no descontará insumos en barra)',
                                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                        ),
                                      ),
                                    )
                                  else
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: recetaItems.length,
                                      separatorBuilder: (_, _) => const Divider(color: AppTheme.borderLight, height: 1),
                                      itemBuilder: (ctx, i) {
                                        final item = recetaItems[i];
                                        return ListTile(
                                          dense: true,
                                          visualDensity: VisualDensity.compact,
                                          contentPadding: EdgeInsets.zero,
                                          leading: const Icon(Icons.science_outlined, color: AppTheme.primaryAmber, size: 18),
                                          title: Text(item['insumo_nombre'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                          subtitle: Text('Descuenta: ${item['cantidad_descuento']} ${item['unidad_medida']}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.errorCoral),
                                            tooltip: 'Remover ingrediente',
                                            onPressed: () {
                                              setEditorState(() {
                                                recetaItems.removeAt(i);
                                              });
                                            },
                                          ),
                                        );
                                      },
                                    ),

                                  const SizedBox(height: 12),

                                  // Selector para añadir un nuevo ingrediente
                                  if (_insumosDisponibles.isNotEmpty)
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: DropdownButtonFormField<String>(
                                            initialValue: nuevoInsumoId,
                                            isExpanded: true,
                                            decoration: const InputDecoration(labelText: 'Insumo', isDense: true),
                                            items: _insumosDisponibles.map((ins) {
                                              return DropdownMenuItem(
                                                value: ins['id'].toString(),
                                                child: Text('${ins['nombre']} (${ins['unidad_medida']})', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                                              );
                                            }).toList(),
                                            onChanged: (val) {
                                              if (val != null) setEditorState(() => nuevoInsumoId = val);
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 2,
                                          child: TextField(
                                            controller: cantInsumoCtrl,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: const InputDecoration(labelText: 'Cantidad', isDense: true),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          style: IconButton.styleFrom(
                                            backgroundColor: AppTheme.primaryAmber,
                                            foregroundColor: Colors.black,
                                          ),
                                          icon: const Icon(Icons.add, size: 18),
                                          tooltip: 'Añadir ingrediente a receta',
                                          onPressed: () {
                                            final cant = double.tryParse(cantInsumoCtrl.text.replaceAll(',', '.'));
                                            if (cant == null || cant <= 0 || nuevoInsumoId == null) return;
                                            final insumoObj = _insumosDisponibles.firstWhere((i) => i['id'] == nuevoInsumoId);

                                            setEditorState(() {
                                              // Si ya existía, reemplazar o sumar
                                              final existingIdx = recetaItems.indexWhere((r) => r['insumo_id'] == nuevoInsumoId);
                                              if (existingIdx >= 0) {
                                                recetaItems[existingIdx]['cantidad_descuento'] = cant;
                                              } else {
                                                recetaItems.add({
                                                  'insumo_id': nuevoInsumoId,
                                                  'insumo_nombre': insumoObj['nombre'],
                                                  'unidad_medida': insumoObj['unidad_medida'],
                                                  'cantidad_descuento': cant,
                                                });
                                              }
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    // Botones Guardar / Cancelar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, false),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryAmber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                          onPressed: () async {
                            final nombre = nombreCtrl.text.trim();
                            final precio = double.tryParse(precioCtrl.text.replaceAll(',', '.'));
                            if (nombre.isEmpty || precio == null || precio < 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Ingrese un nombre y precio válidos'), backgroundColor: AppTheme.errorCoral),
                              );
                              return;
                            }

                            Navigator.pop(dialogCtx, true);
                          },
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: const Text('Guardar Producto'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (guardado == true) {
      final nombre = nombreCtrl.text.trim();
      final precio = double.tryParse(precioCtrl.text.replaceAll(',', '.')) ?? 0.0;

      try {
        String prodId;
        if (isEditing) {
          prodId = producto['id'];
          await SupabaseConfig.client.from('productos').update({
            'nombre': nombre,
            'categoria': catSeleccionada,
            'precio': precio,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', prodId);
        } else {
          final res = await SupabaseConfig.client.from('productos').insert({
            'nombre': nombre,
            'codigo': 'PROD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
            'categoria': catSeleccionada,
            'precio': precio,
            'activo': true,
          }).select().single();
          prodId = res['id'];

          // Crear presentación de venta equivalente para el POS si no existe
          await SupabaseConfig.client.from('presentaciones_venta').insert({
            'nombre': nombre,
            'codigo': 'PRES-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
            'categoria': catSeleccionada,
            'canal_venta': 'BARRA',
            'activo': true,
          });
        }

        // Actualizar precio en historial_precios para la vista POS
        final presList = await SupabaseConfig.client
            .from('presentaciones_venta')
            .select('id')
            .ilike('nombre', nombre)
            .limit(1);
        if (presList.isNotEmpty) {
          final presId = presList.first['id'];
          await SupabaseConfig.client
              .from('historial_precios')
              .update({'precio_unitario': precio})
              .eq('presentacion_id', presId)
              .eq('activo', true);

          await SupabaseConfig.client
              .from('presentaciones_venta')
              .update({'categoria': catSeleccionada})
              .eq('id', presId);
        }

        // Sincronizar tabla de recetas
        await SupabaseConfig.client.from('recetas').delete().eq('producto_id', prodId);
        if (recetaItems.isNotEmpty) {
          final insertRecetas = recetaItems.map((r) => {
            'producto_id': prodId,
            'insumo_id': r['insumo_id'],
            'cantidad_descuento': r['cantidad_descuento'],
          }).toList();
          await SupabaseConfig.client.from('recetas').insert(insertRecetas);
        }

        await _cargarProductos();
        widget.onDataChanged();
        ref.invalidate(catalogoVentasProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Producto "$nombre" guardado exitosamente'),
              backgroundColor: AppTheme.successMint,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar producto: $e'), backgroundColor: AppTheme.errorCoral),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: size.width > 900 ? 760 : size.width * 0.95,
        maxHeight: size.height * 0.88,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera Principal con selector de pestaña
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: AppTheme.primaryAmber, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Gestión de Catálogo',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Selector Segmentado: [ Categorías ] / [ Productos ]
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _tabIndex = 0),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _tabIndex == 0 ? AppTheme.primaryAmber : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            'Categorías (${_categorias.length})',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _tabIndex == 0 ? Colors.black : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _tabIndex = 1),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _tabIndex == 1 ? AppTheme.primaryAmber : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            'Productos (${_productos.length})',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _tabIndex == 1 ? Colors.black : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // CONTENIDO DE LA PESTAÑA
            Expanded(
              child: _tabIndex == 0 ? _buildTabCategorias() : _buildTabProductos(),
            ),
          ],
        ),
      ),
    );
  }

  // --- VISTA PESTAÑA 1: CATEGORÍAS ---
  Widget _buildTabCategorias() {
    return Column(
      children: [
        // Fila para crear categoría
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nuevaCatCtrl,
                decoration: const InputDecoration(
                  hintText: 'Nombre de nueva categoría...',
                  isDense: true,
                  prefixIcon: Icon(Icons.add_box_outlined, size: 18),
                ),
                onSubmitted: (_) => _crearCategoria(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAmber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onPressed: _crearCategoria,
              child: const Text('Añadir', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(color: AppTheme.borderLight, height: 1),

        // Lista de categorías
        Expanded(
          child: _loadingCats
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryAmber))
              : _categorias.isEmpty
                  ? const Center(child: Text('No hay categorías registradas', style: TextStyle(color: AppTheme.textMuted)))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _categorias.length,
                      separatorBuilder: (_, _) => const Divider(color: AppTheme.borderLight, height: 1),
                      itemBuilder: (context, idx) {
                        final cat = _categorias[idx];
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          leading: const Icon(Icons.folder_outlined, color: AppTheme.secondaryCyan, size: 20),
                          title: Text(
                            cat['nombre']?.toString() ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryAmber),
                                tooltip: 'Renombrar categoría',
                                onPressed: () => _editarCategoria(cat),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.errorCoral),
                                tooltip: 'Eliminar categoría',
                                onPressed: () => _eliminarCategoria(cat),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // --- VISTA PESTAÑA 2: PRODUCTOS ---
  Widget _buildTabProductos() {
    // Filtrar lista según selector de categoría y búsqueda
    final prodsFiltrados = _productos.where((p) {
      final matchesSearch = _busquedaProducto.isEmpty ||
          (p['nombre']?.toString().toLowerCase().contains(_busquedaProducto.toLowerCase()) ?? false);

      final matchesCat = _filtroCatProducto == 'TODOS' ||
          (p['categoria']?.toString().toLowerCase() == _filtroCatProducto.toLowerCase());

      return matchesSearch && matchesCat;
    }).toList();

    return Column(
      children: [
        // Barra de Filtros: Dropdown Categoría + Buscador + Botón "+ Nuevo"
        Row(
          children: [
            // Dropdown Categoría
            Expanded(
              flex: 4,
              child: DropdownButtonFormField<String>(
                key: ValueKey('filtro_cat_$_filtroCatProducto'),
                initialValue: _filtroCatProducto,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Filtrar Categoría',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem(value: 'TODOS', child: Text('Todas')),
                  ..._categorias.map((c) {
                    final n = c['nombre'].toString();
                    return DropdownMenuItem(value: n, child: Text(n, overflow: TextOverflow.ellipsis));
                  }),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _filtroCatProducto = val);
                },
              ),
            ),
            const SizedBox(width: 8),

            // Buscador por nombre
            Expanded(
              flex: 5,
              child: TextField(
                controller: _searchProdCtrl,
                decoration: InputDecoration(
                  hintText: 'Buscar producto...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _busquedaProducto.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchProdCtrl.clear();
                            setState(() => _busquedaProducto = '');
                          },
                        )
                      : null,
                ),
                onChanged: (val) => setState(() => _busquedaProducto = val.trim()),
              ),
            ),
            const SizedBox(width: 8),

            // Botón "+ Producto"
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAmber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              icon: const Icon(Icons.add, size: 16, color: Colors.black),
              label: const Text('Nuevo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: () => _abrirEditorProducto(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(color: AppTheme.borderLight, height: 1),

        // Lista de productos con recetas/ingredientes
        Expanded(
          child: _loadingProds
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryAmber))
              : prodsFiltrados.isEmpty
                  ? const Center(child: Text('No se encontraron productos con estos filtros', style: TextStyle(color: AppTheme.textMuted)))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: prodsFiltrados.length,
                      separatorBuilder: (_, _) => const Divider(color: AppTheme.borderLight, height: 1),
                      itemBuilder: (context, idx) {
                        final p = prodsFiltrados[idx];
                        final nombre = p['nombre']?.toString() ?? 'Sin nombre';
                        final categoria = p['categoria']?.toString() ?? 'Otros';
                        final precio = (p['precio'] as num?)?.toDouble() ?? 0.0;
                        final recetas = p['recetas'] as List? ?? [];

                        String descIngredientes = 'Sin receta vinculada';
                        if (recetas.isNotEmpty) {
                          descIngredientes = recetas.map((r) {
                            final iNom = r['insumos'] != null ? r['insumos']['nombre'] : 'Insumo';
                            final iUnd = r['insumos'] != null ? r['insumos']['unidad_medida'] : 'ml';
                            final iCant = r['cantidad_descuento'] ?? 0;
                            return '$iCant$iUnd $iNom';
                          }).join(', ');
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.liquor_rounded, color: AppTheme.primaryAmber, size: 20),
                              ),
                              const SizedBox(width: 10),

                              // Datos: Nombre, Categoría e Ingredientes
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            nombre,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.secondaryCyan.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: AppTheme.secondaryCyan.withValues(alpha: 0.4)),
                                          ),
                                          child: Text(
                                            categoria,
                                            style: const TextStyle(fontSize: 10, color: AppTheme.secondaryCyan, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          Formatters.currency(precio),
                                          style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primaryAmber, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        const Icon(Icons.science_outlined, size: 12, color: AppTheme.textMuted),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            descIngredientes,
                                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryAmber),
                                tooltip: 'Editar producto y receta',
                                onPressed: () => _abrirEditorProducto(producto: p),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
