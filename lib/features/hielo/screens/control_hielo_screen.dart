import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../inventario/models/insumo_model.dart';
import '../../inventario/models/kardex_movimiento_model.dart';
import '../../inventario/services/inventario_service.dart';

/// Panel dual de control de bolsas de hielo (Sede Principal y Sede Secundaria)
class ControlHieloScreen extends StatefulWidget {
  const ControlHieloScreen({super.key});

  @override
  State<ControlHieloScreen> createState() => _ControlHieloScreenState();
}

class _ControlHieloScreenState extends State<ControlHieloScreen> {
  final _service = InventarioService();

  InsumoInventario? _hieloPrincipal;
  InsumoInventario? _hieloSecundaria;
  List<KardexMovimiento> _movimientosHielo = [];

  bool _isLoading = true;
  String _sedePrincipalId = SupabaseConfig.defaultSedePrincipalId;
  String _sedeSecundariaId = SupabaseConfig.defaultSedeSecundariaId;

  @override
  void initState() {
    super.initState();
    _cargarDatosHielo();
  }

  Future<void> _cargarDatosHielo() async {
    setState(() => _isLoading = true);
    try {
      _sedePrincipalId = await SupabaseConfig.getSedePrincipalId();
      _sedeSecundariaId = await SupabaseConfig.getSedeSecundariaId();

      final stockPrincipal = await _service.getStockSede(_sedePrincipalId);
      final stockSecundaria = await _service.getStockSede(_sedeSecundariaId);

      final movs = await _service.getMovimientosKardex(limit: 30);
      final movsFiltrados = movs.where((m) {
        final nombre = m.insumoNombre?.toLowerCase() ?? '';
        final motivo = m.beneficiarioOMotivo?.toLowerCase() ?? '';
        return nombre.contains('hielo') || motivo.contains('hielo');
      }).toList();

      if (mounted) {
        setState(() {
          _hieloPrincipal = stockPrincipal.firstWhere(
            (i) => i.nombre.toLowerCase().contains('hielo') || i.unidadMedida == 'bolsa_hielo',
            orElse: () => InsumoInventario(
              id: '',
              sedeId: _sedePrincipalId,
              nombre: 'Bolsa de Hielo',
              unidadMedida: 'bolsa_hielo',
              stockActual: 0,
              stockMinimo: 5,
              costoUnitario: 1.5,
            ),
          );

          _hieloSecundaria = stockSecundaria.firstWhere(
            (i) => i.nombre.toLowerCase().contains('hielo') || i.unidadMedida == 'bolsa_hielo',
            orElse: () => InsumoInventario(
              id: '',
              sedeId: _sedeSecundariaId,
              nombre: 'Bolsa de Hielo',
              unidadMedida: 'bolsa_hielo',
              stockActual: 0,
              stockMinimo: 5,
              costoUnitario: 1.5,
            ),
          );

          _movimientosHielo = movsFiltrados;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos de hielo: $e'),
            backgroundColor: AppTheme.errorCoral,
          ),
        );
      }
    }
  }

  void _mostrarModalOperacionHielo(String tipo) {
    final cantController = TextEditingController();
    final motivoController = TextEditingController();

    String titulo;
    Color colorAccion;
    if (tipo == 'COMPRA') {
      titulo = 'Comprar / Ingresar Bolsas de Hielo';
      colorAccion = AppTheme.successMint;
      motivoController.text = 'Compra de bolsas de hielo';
    } else if (tipo == 'MERMA') {
      titulo = 'Merma por Deshielo / Pérdida';
      colorAccion = AppTheme.errorCoral;
      motivoController.text = 'Pérdida por deshielo en cava';
    } else {
      titulo = 'Trasladar Hielo a Sede Secundaria';
      colorAccion = AppTheme.secondaryCyan;
      motivoController.text = 'Traslado de bolsas de hielo a Sede Secundaria';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cantController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Cantidad de Bolsas *',
                hintText: 'Ej. 10',
                prefixIcon: Icon(Icons.ac_unit, color: AppTheme.secondaryCyan),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motivoController,
              decoration: const InputDecoration(
                labelText: 'Motivo / Detalle',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colorAccion),
            child: const Text('REGISTRAR'),
            onPressed: () async {
              final cant = double.tryParse(cantController.text);
              if (cant == null || cant <= 0) return;

              Navigator.pop(ctx);
              setState(() => _isLoading = true);

              try {
                await _service.registrarMovimientoHielo(
                  sedeId: _sedePrincipalId,
                  tipoMovimiento: tipo,
                  cantidad: cant,
                  motivo: motivoController.text.trim(),
                  sedeDestinoId: tipo == 'TRASLADO' ? _sedeSecundariaId : null,
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Operación de hielo registrada exitosamente'),
                      backgroundColor: AppTheme.successMint,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppTheme.errorCoral,
                    ),
                  );
                }
              } finally {
                _cargarDatosHielo();
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Control de Bolsas de Hielo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatosHielo,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // PANEL DUAL DE BOLSAS DE HIELO
                const Text(
                  'PANEL DUAL DE INVENTARIO DE HIELO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryAmber,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    // Sede Principal
                    Expanded(
                      child: _buildTarjetaSedeHielo(
                        titulo: SupabaseConfig.sedePrincipalNombre,
                        subtitulo: 'Barra Operativa Principal',
                        insumo: _hieloPrincipal,
                        esPrincipal: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Sede Secundaria
                    Expanded(
                      child: _buildTarjetaSedeHielo(
                        titulo: SupabaseConfig.sedeSecundariaNombre,
                        subtitulo: 'Depósito / Respaldo',
                        insumo: _hieloSecundaria,
                        esPrincipal: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ACCIONES RÁPIDAS EXCLUSIVAS DE HIELO
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'ACCIONES RÁPIDAS DE HIELO',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondaryCyan,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 52,
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.successMint,
                                    foregroundColor: AppTheme.background,
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => _mostrarModalOperacionHielo('COMPRA'),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_shopping_cart, size: 18),
                                      SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Comprar Hielo',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.secondaryCyan,
                                    foregroundColor: AppTheme.background,
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => _mostrarModalOperacionHielo('TRASLADO'),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.swap_horiz, size: 18),
                                      SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Trasladar Hielo',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.errorCoral,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => _mostrarModalOperacionHielo('MERMA'),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.water_drop_outlined, size: 18),
                                      SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Merma / Deshielo',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // HISTORIAL DE MOVIMIENTOS DE HIELO
                const Text(
                  'HISTORIAL DE MOVIMIENTOS DE HIELO',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),

                if (_movimientosHielo.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          'No hay movimientos de hielo registrados',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ),
                    ),
                  )
                else
                  ..._movimientosHielo.map((m) {
                    IconData icon;
                    Color color;
                    String prefijo;

                    if (m.tipoMovimiento == 'ENTRADA_COMPRA' || m.tipoMovimiento == 'COMPRA') {
                      icon = Icons.add_circle;
                      color = AppTheme.successMint;
                      prefijo = '+';
                    } else if (m.tipoMovimiento == 'MERMA') {
                      icon = Icons.water_drop;
                      color = AppTheme.errorCoral;
                      prefijo = '-';
                    } else {
                      icon = Icons.swap_horiz;
                      color = AppTheme.secondaryCyan;
                      prefijo = '⇄ ';
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        title: Text(
                          m.beneficiarioOMotivo ?? m.tipoMovimiento,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        subtitle: Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(m.fecha),
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                        trailing: Text(
                          '$prefijo${m.cantidad.toStringAsFixed(0)} bolsas',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }

  Widget _buildTarjetaSedeHielo({
    required String titulo,
    required String subtitulo,
    required InsumoInventario? insumo,
    required bool esPrincipal,
  }) {
    final stock = insumo?.stockActual ?? 0.0;
    final minimo = insumo?.stockMinimo ?? 5.0;

    Color estadoColor;
    String estadoTexto;
    if (stock <= 0) {
      estadoColor = AppTheme.errorCoral;
      estadoTexto = 'SIN HIELO';
    } else if (stock <= minimo) {
      estadoColor = AppTheme.warningAmber;
      estadoTexto = 'BAJO HIELO';
    } else {
      estadoColor = AppTheme.secondaryCyan;
      estadoTexto = 'ABASTECIDO';
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: esPrincipal ? AppTheme.primaryAmber : AppTheme.borderLight,
          width: esPrincipal ? 1.8 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  Icons.ac_unit,
                  size: 28,
                  color: esPrincipal ? AppTheme.primaryAmber : AppTheme.secondaryCyan,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: estadoColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: estadoColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    estadoTexto,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: estadoColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              titulo,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              subtitulo,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            Text(
              stock.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: estadoColor,
              ),
            ),
            const Text(
              'Bolsas disponibles',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
