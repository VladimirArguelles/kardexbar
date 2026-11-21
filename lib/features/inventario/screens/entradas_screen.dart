import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../models/insumo_model.dart';
import '../models/kardex_movimiento_model.dart';
import '../services/inventario_service.dart';

/// Pantalla para el registro de compras y recepción de insumos
class EntradasScreen extends StatefulWidget {
  const EntradasScreen({super.key});

  @override
  State<EntradasScreen> createState() => _EntradasScreenState();
}

class _EntradasScreenState extends State<EntradasScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = InventarioService();

  final _cantidadController = TextEditingController();
  final _costoController = TextEditingController();
  final _motivoController = TextEditingController();

  List<InsumoInventario> _insumos = [];
  InsumoInventario? _insumoSeleccionado;
  List<KardexMovimiento> _ultimasEntradas = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _costoController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final sedeId = await SupabaseConfig.getSedePrincipalId();
      final insumos = await _service.getStockSede(sedeId);
      final entradas = await _service.getMovimientosKardex(
        sedeId: sedeId,
        tipoMovimiento: 'ENTRADA_COMPRA',
        limit: 15,
      );

      if (mounted) {
        setState(() {
          _insumos = insumos;
          if (_insumos.isNotEmpty && _insumoSeleccionado == null) {
            _insumoSeleccionado = _insumos.first;
            _costoController.text = _insumoSeleccionado!.costoUnitario.toStringAsFixed(2);
          }
          _ultimasEntradas = entradas;
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

  Future<void> _guardarEntrada() async {
    if (!_formKey.currentState!.validate() || _insumoSeleccionado == null) return;

    setState(() => _isSaving = true);
    try {
      final sedeId = await SupabaseConfig.getSedePrincipalId();
      final cantidad = double.parse(_cantidadController.text);
      final costo = double.tryParse(_costoController.text) ?? 0.0;
      final motivo = _motivoController.text.trim().isEmpty
          ? 'Compra directa / Abastecimiento'
          : _motivoController.text.trim();

      await _service.registrarEntradaCompra(
        insumoId: _insumoSeleccionado!.id,
        sedeId: sedeId,
        cantidad: cantidad,
        costoUnitario: costo,
        proveedorOMotivo: motivo,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Entrada de compra registrada exitosamente en Kardex!'),
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
            content: Text('Error al registrar compra: $e'),
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
        title: const Text('Compras / Entradas'),
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
                // Formulario de Entrada
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'INGRESO DE STOCK POR COMPRA',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryAmber,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Selector de Insumo con isExpanded y elipsis anti-desborde
                          DropdownButtonFormField<InsumoInventario>(
                            initialValue: _insumoSeleccionado,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Insumo a Ingresar *',
                              prefixIcon: Icon(Icons.inventory_2, color: AppTheme.primaryAmber),
                            ),
                            items: _insumos.map((i) {
                              return DropdownMenuItem(
                                value: i,
                                child: Text(
                                  '${i.nombre} (${i.unidadMedida})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _insumoSeleccionado = val;
                                if (val != null) {
                                  _costoController.text = val.costoUnitario.toStringAsFixed(2);
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 14),

                          // Cantidad y Costo Unitario
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _cantidadController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Cantidad *',
                                    hintText: 'Ej. 24',
                                    suffixText: _insumoSeleccionado?.unidadMedida ?? '',
                                    prefixIcon: const Icon(Icons.add_circle, color: AppTheme.successMint),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) return 'Ingrese cantidad';
                                    final num? n = num.tryParse(val);
                                    if (n == null || n <= 0) return 'Mayor a 0';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _costoController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Costo Unit (\$)',
                                    hintText: 'Ej. 1.25',
                                    prefixIcon: Icon(Icons.attach_money, color: AppTheme.secondaryCyan),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Motivo / Proveedor
                          TextFormField(
                            controller: _motivoController,
                            decoration: const InputDecoration(
                              labelText: 'Proveedor o Factura / Motivo',
                              hintText: 'Ej. Distribuidor Polar / Factura #402',
                              prefixIcon: Icon(Icons.description, color: AppTheme.textMuted),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Botón de Guardado
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.successMint,
                              foregroundColor: AppTheme.background,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.check, size: 20),
                            label: const Text(
                              'ASENTAR EN KARDEX',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            onPressed: _isSaving ? null : _guardarEntrada,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Historial de Compras Recientes
                const Text(
                  'ÚLTIMAS ENTRADAS REGISTRADAS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),

                if (_ultimasEntradas.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          'No hay compras registradas recientemente',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ),
                    ),
                  )
                else
                  ..._ultimasEntradas.map((k) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF0F3D33),
                          child: Icon(Icons.arrow_downward, color: AppTheme.successMint, size: 20),
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
                          '+${k.cantidad.toStringAsFixed(1)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.successMint,
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
