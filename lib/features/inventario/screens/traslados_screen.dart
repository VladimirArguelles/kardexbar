import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../models/insumo_model.dart';
import '../models/kardex_movimiento_model.dart';
import '../services/inventario_service.dart';

/// Pantalla para traslados de inventario entre Sede Principal y Sede Secundaria
class TrasladosScreen extends StatefulWidget {
  const TrasladosScreen({super.key});

  @override
  State<TrasladosScreen> createState() => _TrasladosScreenState();
}

class _TrasladosScreenState extends State<TrasladosScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = InventarioService();

  final _cantidadController = TextEditingController();
  final _motivoController = TextEditingController();

  // Direcciones: 0: Principal -> Secundaria, 1: Secundaria -> Principal
  int _direccion = 0;

  List<InsumoInventario> _insumosOrigen = [];
  InsumoInventario? _insumoSeleccionado;
  List<KardexMovimiento> _ultimosTraslados = [];
  bool _isLoading = true;
  bool _isSaving = false;

  String _sedePrincipalId = SupabaseConfig.defaultSedePrincipalId;
  String _sedeSecundariaId = SupabaseConfig.defaultSedeSecundariaId;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      _sedePrincipalId = await SupabaseConfig.getSedePrincipalId();
      _sedeSecundariaId = await SupabaseConfig.getSedeSecundariaId();

      final origenId = _direccion == 0 ? _sedePrincipalId : _sedeSecundariaId;
      final insumos = await _service.getStockSede(origenId);
      final traslados = await _service.getMovimientosKardex(
        tipoMovimiento: 'TRASLADO',
        limit: 15,
      );

      if (mounted) {
        setState(() {
          _insumosOrigen = insumos;
          if (_insumosOrigen.isNotEmpty) {
            _insumoSeleccionado = _insumosOrigen.first;
          } else {
            _insumoSeleccionado = null;
          }
          _ultimosTraslados = traslados;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: AppTheme.errorCoral,
          ),
        );
      }
    }
  }

  Future<void> _ejecutarTraslado() async {
    if (!_formKey.currentState!.validate() || _insumoSeleccionado == null) return;

    setState(() => _isSaving = true);
    try {
      final origenId = _direccion == 0 ? _sedePrincipalId : _sedeSecundariaId;
      final destinoId = _direccion == 0 ? _sedeSecundariaId : _sedePrincipalId;
      final cantidad = double.parse(_cantidadController.text);
      final motivo = _motivoController.text.trim().isEmpty
          ? 'Reabastecimiento inter-sede'
          : _motivoController.text.trim();

      await _service.registrarTrasladoSedes(
        insumoNombre: _insumoSeleccionado!.nombre,
        sedeOrigenId: origenId,
        sedeDestinoId: destinoId,
        cantidad: cantidad,
        motivo: motivo,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Traslado inter-sede registrado con éxito!'),
            backgroundColor: AppTheme.successMint,
          ),
        );
        _cantidadController.clear();
        _motivoController.clear();
        _cargarDatos();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al ejecutar traslado: $e'),
            backgroundColor: AppTheme.errorCoral,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombreOrigen = _direccion == 0
        ? SupabaseConfig.sedePrincipalNombre
        : SupabaseConfig.sedeSecundariaNombre;
    final nombreDestino = _direccion == 0
        ? SupabaseConfig.sedeSecundariaNombre
        : SupabaseConfig.sedePrincipalNombre;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Traslados Inter-Sedes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Selector de Dirección
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'DIRECCIÓN DEL TRASLADO',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryAmber,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(
                              value: 0,
                              label: Text('Principal ➔ Secundaria'),
                              icon: Icon(Icons.arrow_forward),
                            ),
                            ButtonSegment(
                              value: 1,
                              label: Text('Secundaria ➔ Principal'),
                              icon: Icon(Icons.arrow_back),
                            ),
                          ],
                          selected: {_direccion},
                          onSelectionChanged: (set) {
                            setState(() => _direccion = set.first);
                            _cargarDatos();
                          },
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Text('ORIGEN', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                  Text(nombreOrigen, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.secondaryCyan)),
                                ],
                              ),
                              const Icon(Icons.east, color: AppTheme.primaryAmber, size: 20),
                              Column(
                                children: [
                                  const Text('DESTINO', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                  Text(nombreDestino, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.successMint)),
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

                // Formulario de Traslado
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'DATOS DEL TRASLADO FÍSICO',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryAmber,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Selector Insumo Origen
                          DropdownButtonFormField<InsumoInventario>(
                            initialValue: _insumoSeleccionado,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Insumo a Trasladar * (Desde $nombreOrigen)',
                              prefixIcon: const Icon(Icons.inventory_2, color: AppTheme.secondaryCyan),
                            ),
                            items: _insumosOrigen.map((i) {
                              return DropdownMenuItem(
                                value: i,
                                child: Text(
                                  '${i.nombre} (Stock: ${i.stockActual.toStringAsFixed(1)} ${i.unidadMedida})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _insumoSeleccionado = val),
                          ),
                          const SizedBox(height: 14),

                          // Cantidad a trasladar
                          TextFormField(
                            controller: _cantidadController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Cantidad a Trasladar *',
                              hintText: 'Ej. 12',
                              suffixText: _insumoSeleccionado?.unidadMedida ?? '',
                              prefixIcon: const Icon(Icons.send, color: AppTheme.primaryAmber),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Ingrese cantidad';
                              final num? n = num.tryParse(val);
                              if (n == null || n <= 0) return 'Mayor a 0';
                              if (_insumoSeleccionado != null && n > _insumoSeleccionado!.stockActual) {
                                return 'Supera el stock disponible (${_insumoSeleccionado!.stockActual})';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Motivo
                          TextFormField(
                            controller: _motivoController,
                            decoration: const InputDecoration(
                              labelText: 'Motivo del Traslado',
                              hintText: 'Ej. Surtido barra / Alta demanda fin de semana',
                              prefixIcon: Icon(Icons.notes, color: AppTheme.textMuted),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Botón de Envío
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.secondaryCyan,
                              foregroundColor: AppTheme.background,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.background),
                                  )
                                : const Icon(Icons.swap_horiz, size: 22),
                            label: const Text(
                              'EJECUTAR TRASLADO ATÓMICO',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            onPressed: _isSaving ? null : _ejecutarTraslado,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Historial de Traslados
                const Text(
                  'HISTORIAL DE TRASLADOS ENTRE SEDES',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),

                if (_ultimosTraslados.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          'No hay traslados registrados recientemente',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ),
                    ),
                  )
                else
                  ..._ultimosTraslados.map((k) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF0A3045),
                          child: Icon(Icons.swap_horiz, color: AppTheme.secondaryCyan, size: 22),
                        ),
                        title: Text(
                          k.insumoNombre ?? 'Insumo',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          '${DateFormat('dd/MM/yyyy HH:mm').format(k.fecha)}  •  ${k.beneficiarioOMotivo ?? ''}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                        trailing: Text(
                          '${k.cantidad.toStringAsFixed(1)} unid',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondaryCyan,
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
