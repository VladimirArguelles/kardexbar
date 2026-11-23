import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../models/insumo_model.dart';
import '../models/kardex_movimiento_model.dart';
import '../services/inventario_service.dart';

/// Pantalla para el registro de pérdidas, roturas y mermas en barra
class MermasScreen extends StatefulWidget {
  const MermasScreen({super.key});

  @override
  State<MermasScreen> createState() => _MermasScreenState();
}

class _MermasScreenState extends State<MermasScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = InventarioService();

  final _cantidadController = TextEditingController();
  final _motivoController = TextEditingController();

  List<InsumoInventario> _insumos = [];
  InsumoInventario? _insumoSeleccionado;
  List<KardexMovimiento> _ultimasMermas = [];
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _motivosFrecuentes = [
    'Botella rota por caída',
    'Derrame en servicio de barra',
    'Producto en mal estado / vencido',
    'Deshielo excesivo',
    'Agotamiento / Descarte de preparación',
  ];

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
      final sedeId = await SupabaseConfig.getSedePrincipalId();
      final insumos = await _service.getStockSede(sedeId);
      final mermas = await _service.getMovimientosKardex(
        sedeId: sedeId,
        tipoMovimiento: 'MERMA',
        limit: 15,
      );

      if (mounted) {
        setState(() {
          _insumos = insumos;
          if (_insumos.isNotEmpty && _insumoSeleccionado == null) {
            _insumoSeleccionado = _insumos.first;
          }
          _ultimasMermas = mermas;
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

  Future<void> _guardarMerma() async {
    if (!_formKey.currentState!.validate() || _insumoSeleccionado == null) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final sedeId = await SupabaseConfig.getSedePrincipalId();
      final cantidad = double.parse(_cantidadController.text);
      final motivo = _motivoController.text.trim();

      await _service.registrarMerma(
        insumoId: _insumoSeleccionado!.id,
        sedeId: sedeId,
        cantidad: cantidad,
        motivo: motivo,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Merma registrada exitosamente en Kardex!'),
            backgroundColor: AppTheme.warningAmber,
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
            content: Text('Error al registrar merma: $e'),
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Mermas y Roturas'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarDatos),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Formulario de Merma
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.report_problem,
                                color: AppTheme.errorCoral,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'ASENTAR PÉRDIDA O ROTURA FÍSICA',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.errorCoral,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Selector Insumo
                          DropdownButtonFormField<InsumoInventario>(
                            initialValue: _insumoSeleccionado,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Insumo Mermado *',
                              prefixIcon: Icon(
                                Icons.inventory_2,
                                color: AppTheme.errorCoral,
                              ),
                            ),
                            items: _insumos.map((i) {
                              return DropdownMenuItem(
                                value: i,
                                child: Text(
                                  '${i.nombre} (Stock: ${i.stockActual.toStringAsFixed(1)} ${i.unidadMedida})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => _insumoSeleccionado = val),
                          ),
                          const SizedBox(height: 14),

                          // Cantidad mermada
                          TextFormField(
                            controller: _cantidadController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Cantidad Perdida *',
                              hintText: 'Ej. 1 o 250',
                              suffixText:
                                  _insumoSeleccionado?.unidadMedida ?? '',
                              prefixIcon: const Icon(
                                Icons.remove_circle,
                                color: AppTheme.errorCoral,
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Ingrese cantidad';
                              }
                              final num? n = num.tryParse(val);
                              if (n == null || n <= 0) return 'Mayor a 0';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Motivo detallado
                          TextFormField(
                            controller: _motivoController,
                            decoration: const InputDecoration(
                              labelText: 'Motivo de la Merma *',
                              hintText: 'Ej. Botella rota en mesa / derrame accidental',
                              prefixIcon: Icon(
                                Icons.description,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Especifique el motivo';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),

                          // Chips de motivos frecuentes
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: _motivosFrecuentes.map((mot) {
                              return ActionChip(
                                label: Text(
                                  mot,
                                  style: const TextStyle(fontSize: 10),
                                ),
                                backgroundColor: AppTheme.surfaceVariant,
                                onPressed: () {
                                  setState(() {
                                    _motivoController.text = mot;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),

                          // Botón de Envío
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.errorCoral,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.delete_outline, size: 20),
                            label: const Text(
                              'DESCONTAR MERMA EN KARDEX',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            onPressed: _isSaving ? null : _guardarMerma,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Historial de Mermas
                const Text(
                  'HISTORIAL DE MERMAS RECIENTES',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),

                if (_ultimasMermas.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          'No hay mermas registradas recientemente',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ),
                    ),
                  )
                else
                  ..._ultimasMermas.map((k) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF3D1621),
                          child: Icon(
                            Icons.delete_forever,
                            color: AppTheme.errorCoral,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          k.insumoNombre ?? 'Insumo',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          '${DateFormat('dd/MM/yyyy HH:mm').format(k.fecha)}  •  ${k.beneficiarioOMotivo ?? ''}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        trailing: Text(
                          '-${k.cantidad.toStringAsFixed(1)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.errorCoral,
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
