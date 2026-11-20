import 'package:flutter/material.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/export_print_widget.dart';
import '../models/insumo_model.dart';
import '../services/inventario_service.dart';
import 'entradas_screen.dart';
import 'mermas_screen.dart';
import 'traslados_screen.dart';

/// Pantalla de Stock Vivo para Sede Principal con alertas visuales de nivel
class StockVivoScreen extends StatefulWidget {
  const StockVivoScreen({super.key});

  @override
  State<StockVivoScreen> createState() => _StockVivoScreenState();
}

class _StockVivoScreenState extends State<StockVivoScreen> {
  final _service = InventarioService();
  final _searchController = TextEditingController();

  List<InsumoInventario> _insumos = [];
  bool _isLoading = true;
  String _filtroAlerta = 'TODOS'; // 'TODOS', 'OPTIMO', 'BAJO', 'AGOTADO'

  @override
  void initState() {
    super.initState();
    _cargarStock();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarStock() async {
    setState(() => _isLoading = true);
    try {
      final sedeId = await SupabaseConfig.getSedePrincipalId();
      final list = await _service.getStockSede(sedeId);
      if (mounted) {
        setState(() {
          _insumos = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar inventario: $e'),
            backgroundColor: AppTheme.errorCoral,
          ),
        );
      }
    }
  }

  int get _countAgotados => _insumos.where((i) => i.isAgotado).length;
  int get _countMinimos => _insumos.where((i) => i.isMinimo).length;
  int get _countOptimos => _insumos.where((i) => i.isOptimo).length;

  List<InsumoInventario> get _insumosFiltrados {
    final query = _searchController.text.trim().toLowerCase();
    return _insumos.where((i) {
      final matchesSearch = i.nombre.toLowerCase().contains(query);
      if (!matchesSearch) return false;

      if (_filtroAlerta == 'AGOTADO') return i.isAgotado;
      if (_filtroAlerta == 'BAJO') return i.isMinimo;
      if (_filtroAlerta == 'OPTIMO') return i.isOptimo;
      return true;
    }).toList();
  }

  void _exportarStockReport() {
    final filas = _insumos.map((i) {
      return [
        i.nombre,
        i.unidadMedida,
        i.stockActual.toStringAsFixed(2),
        i.stockMinimo.toStringAsFixed(2),
        i.estadoAlerta,
        '\$${i.costoUnitario.toStringAsFixed(2)}',
      ];
    }).toList();

    ExportPrintWidget.showModal(
      context,
      data: ReporteExportData(
        titulo: 'Inventario Físico - Stock Vivo',
        subtitulo: SupabaseConfig.sedePrincipalNombre,
        fecha: DateTime.now(),
        resumenKpis: {
          'Total Insumos': '${_insumos.length}',
          'Stock Óptimo': '$_countOptimos',
          'En Mínimo': '$_countMinimos',
          'Agotados': '$_countAgotados',
        },
        columnasTabla: ['Insumo', 'Unidad', 'Stock', 'Mínimo', 'Estado', 'Costo Unit'],
        filasTabla: filas,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Stock Vivo - Barra Principal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar stock',
            onPressed: _cargarStock,
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Exportar informe de inventario',
            onPressed: _insumos.isEmpty ? null : _exportarStockReport,
          ),
        ],
      ),
      body: Column(
        children: [
          // Tarjetas KPI de Estado de Inventario
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            child: Row(
              children: [
                _buildKpiCard(
                  'ÓPTIMO',
                  '$_countOptimos',
                  AppTheme.successMint,
                  Icons.check_circle_outline,
                  'OPTIMO',
                ),
                const SizedBox(width: 8),
                _buildKpiCard(
                  'MÍNIMO',
                  '$_countMinimos',
                  AppTheme.warningAmber,
                  Icons.warning_amber_outlined,
                  'BAJO',
                ),
                const SizedBox(width: 8),
                _buildKpiCard(
                  'CRÍTICO',
                  '$_countAgotados',
                  AppTheme.errorCoral,
                  Icons.cancel_outlined,
                  'AGOTADO',
                ),
              ],
            ),
          ),

          // Buscador y Filtro
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar insumo (ej. Polar, Hielo, Ron)...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.secondaryCyan),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 10),

          // Acciones Rápidas del Bartender
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      foregroundColor: AppTheme.successMint,
                      side: const BorderSide(color: AppTheme.successMint),
                    ),
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text('Entrada / Compra', style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EntradasScreen()),
                      );
                      _cargarStock();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      foregroundColor: AppTheme.secondaryCyan,
                      side: const BorderSide(color: AppTheme.secondaryCyan),
                    ),
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Traslado Sedes', style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TrasladosScreen()),
                      );
                      _cargarStock();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      foregroundColor: AppTheme.errorCoral,
                      side: const BorderSide(color: AppTheme.errorCoral),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Merma / Rotura', style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MermasScreen()),
                      );
                      _cargarStock();
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Lista de Insumos con Alertas Visuales
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _insumosFiltrados.isEmpty
                    ? const Center(
                        child: Text(
                          'No se encontraron insumos',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        itemCount: _insumosFiltrados.length,
                        itemBuilder: (context, index) {
                          final insumo = _insumosFiltrados[index];
                          return _buildInsumoCard(insumo);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(
    String label,
    String value,
    Color color,
    IconData icon,
    String filtro,
  ) {
    final isSelected = _filtroAlerta == filtro;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _filtroAlerta = isSelected ? 'TODOS' : filtro;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.2) : AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : AppTheme.borderLight,
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsumoCard(InsumoInventario item) {
    Color badgeColor;
    String badgeText;
    if (item.isAgotado) {
      badgeColor = AppTheme.errorCoral;
      badgeText = 'AGOTADO';
    } else if (item.isMinimo) {
      badgeColor = AppTheme.warningAmber;
      badgeText = 'STOCK MÍNIMO';
    } else {
      badgeColor = AppTheme.successMint;
      badgeText = 'ÓPTIMO';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: item.isAgotado
              ? AppTheme.errorCoral.withValues(alpha: 0.6)
              : (item.isMinimo
                  ? AppTheme.warningAmber.withValues(alpha: 0.6)
                  : AppTheme.borderLight),
          width: item.isAgotado || item.isMinimo ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Indicador visual de estado
            Container(
              width: 4,
              height: 44,
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            // Información principal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nombre,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        'Unidad: ${item.unidadMedida}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Mínimo: ${item.stockMinimo.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Stock actual y badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.stockActual.toStringAsFixed(item.unidadMedida == 'unidad' || item.unidadMedida == 'bolsa_hielo' ? 0 : 1)} ${item.unidadMedida}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: badgeColor,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
