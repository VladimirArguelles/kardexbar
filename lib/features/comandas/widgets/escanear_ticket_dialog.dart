import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../models/comanda_model.dart';
import '../models/ticket_escaneado_model.dart';
import '../services/ticket_scanner_service.dart';

/// Resultado del diálogo de escaneo tras la confirmación del usuario
class EscaneoTicketConfirmado {
  final String? numeroTicket;
  final String? cliente;
  final String? mesero;
  final List<ItemTicketEscaneado> items;

  EscaneoTicketConfirmado({
    this.numeroTicket,
    this.cliente,
    this.mesero,
    required this.items,
  });
}

/// Diálogo interactivo táctil para escanear tickets físicos y revisar las sugerencias de la IA
class EscanearTicketDialog extends StatefulWidget {
  final List<ProductoBarra> catalogoProductos;

  const EscanearTicketDialog({super.key, required this.catalogoProductos});

  /// Muestra el diálogo modal y retorna el resultado confirmado o null si se cancela
  static Future<EscaneoTicketConfirmado?> mostrar(
    BuildContext context, {
    required List<ProductoBarra> catalogo,
  }) {
    return showDialog<EscaneoTicketConfirmado>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EscanearTicketDialog(catalogoProductos: catalogo),
    );
  }

  @override
  State<EscanearTicketDialog> createState() => _EscanearTicketDialogState();
}

class _EscanearTicketDialogState extends State<EscanearTicketDialog> {
  final TicketScannerService _scannerService = TicketScannerService();

  Uint8List? _imageBytes;
  bool _procesando = false;
  String? _mensajeError;

  // Controladores de metadatos detectados
  final TextEditingController _ticketController = TextEditingController();
  final TextEditingController _clienteController = TextEditingController();
  final TextEditingController _meseroController = TextEditingController();

  List<ItemTicketEscaneado> _itemsDetectados = [];

  @override
  void dispose() {
    _ticketController.dispose();
    _clienteController.dispose();
    _meseroController.dispose();
    super.dispose();
  }

  Future<void> _capturarCon(ImageSource source) async {
    setState(() {
      _mensajeError = null;
    });

    try {
      final XFile? file = source == ImageSource.camera
          ? await _scannerService.capturarFotoCamara()
          : await _scannerService.seleccionarFotoGaleria();

      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      setState(() {
        _imageBytes = bytes;
        _procesando = true;
      });

      final result = await _scannerService.escanearTicket(
        imageBytes: bytes,
        productosDisponibles: widget.catalogoProductos,
      );

      if (!mounted) return;

      setState(() {
        _procesando = false;
        _mensajeError = null;
        _ticketController.text = result.numeroTicket ?? '';
        _clienteController.text = result.cliente ?? '';
        _meseroController.text = result.mesero ?? '';
        _itemsDetectados = List.from(result.items);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _procesando = false;
        _imageBytes = null;
        _mensajeError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _incrementarCantidad(int index) {
    setState(() {
      _itemsDetectados[index].cantidad += 1.0;
    });
  }

  void _decrementarCantidad(int index) {
    setState(() {
      if (_itemsDetectados[index].cantidad > 1.0) {
        _itemsDetectados[index].cantidad -= 1.0;
      } else {
        _itemsDetectados.removeAt(index);
      }
    });
  }

  void _eliminarItem(int index) {
    setState(() {
      _itemsDetectados.removeAt(index);
    });
  }

  void _cambiarProducto(int index, ProductoBarra? nuevoProducto) {
    if (nuevoProducto == null) return;
    setState(() {
      _itemsDetectados[index].productoSugerido = nuevoProducto;
      _itemsDetectados[index].productoId = nuevoProducto.id;
    });
  }

  void _confirmarYAplicar() {
    final itemsValidos = _itemsDetectados
        .where((i) => i.estaVinculado)
        .toList();

    if (itemsValidos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay productos vinculados al catálogo para agregar a la comanda.',
          ),
          backgroundColor: AppTheme.errorCoral,
        ),
      );
      return;
    }

    final resultado = EscaneoTicketConfirmado(
      numeroTicket: _ticketController.text.trim().isNotEmpty
          ? _ticketController.text.trim()
          : null,
      cliente: _clienteController.text.trim().isNotEmpty
          ? _clienteController.text.trim()
          : null,
      mesero: _meseroController.text.trim().isNotEmpty
          ? _meseroController.text.trim()
          : null,
      items: itemsValidos,
    );

    Navigator.of(context).pop(resultado);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final esPantallaPequena = size.width < 600;

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.borderLight, width: 1.5),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: esPantallaPequena ? 12 : 32,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: size.height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado del diálogo
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.document_scanner,
                      color: AppTheme.primaryAmber,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Escanear Comanda / Ticket',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Digitalización automática con visión artificial y Gemini',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Cuerpo según estado
              Expanded(
                child: _procesando
                    ? _buildVistaProcesando()
                    : (_imageBytes == null || _mensajeError != null)
                    ? _buildVistaSeleccionarOrigen()
                    : _buildVistaRevision(),
              ),

              const SizedBox(height: 12),

              // Botones de acción inferiores
              if (!_procesando)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    if (_imageBytes != null && _itemsDetectados.isNotEmpty)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline, size: 20),
                        label: Text(
                          'Agregar ${_itemsDetectados.where((i) => i.estaVinculado).length} Productos a Ronda',
                        ),
                        onPressed: _confirmarYAplicar,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Vista inicial: Selección de origen (Cámara o Galería)
  Widget _buildVistaSeleccionarOrigen() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_enhance_outlined,
            size: _mensajeError != null ? 48 : 60,
            color: AppTheme.primaryAmber,
          ),
          const SizedBox(height: 12),
          const Text(
            'Selecciona el método de captura de la comanda',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Asegúrate de que el ticket físico tenga buena iluminación y los textos de barra o números sean legibles.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: _mensajeError != null ? 14 : 22),
          if (_mensajeError != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorCoral.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.errorCoral),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppTheme.errorCoral,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _mensajeError!,
                      style: const TextStyle(
                        color: AppTheme.errorCoral,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Wrap(
            spacing: 14,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              SizedBox(
                width: 200,
                height: 80,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceVariant,
                    foregroundColor: AppTheme.primaryAmber,
                    side: const BorderSide(
                      color: AppTheme.primaryAmber,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _capturarCon(ImageSource.camera),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 28),
                      SizedBox(height: 4),
                      Text(
                        'Tomar Foto (Cámara)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 200,
                height: 80,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceVariant,
                    foregroundColor: AppTheme.secondaryCyan,
                    side: const BorderSide(
                      color: AppTheme.secondaryCyan,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _capturarCon(ImageSource.gallery),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library, size: 28),
                      SizedBox(height: 4),
                      Text(
                        'Galería o Archivo',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// Vista mientras la Edge Function procesa con Gemini Vision
  Widget _buildVistaProcesando() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_imageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 120,
                height: 120,
                child: Image.memory(_imageBytes!, fit: BoxFit.cover),
              ),
            ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: AppTheme.primaryAmber),
          const SizedBox(height: 20),
          const Text(
            'Analizando comanda física...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Gemini Vision está interpretando abreviaturas de barra y cruzando productos con el catálogo',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Vista de revisión de los ítems detectados y datos de la comanda
  Widget _buildVistaRevision() {
    final vinculados = _itemsDetectados.where((i) => i.estaVinculado).length;
    final totalDetectados = _itemsDetectados.length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner de estado de detección y botón para recapturar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(
              children: [
                if (_imageBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detección: $vinculados de $totalDetectados productos vinculados',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Text(
                        'Revisa las cantidades o asocia productos no reconocidos.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text(
                    'Otra foto',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: () {
                    setState(() {
                      _imageBytes = null;
                      _itemsDetectados = [];
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Campos detectados: Ticket, Cliente, Mesero
          const Text(
            'DATOS DEL TICKET DETECTADOS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _ticketController,
                  decoration: const InputDecoration(
                    labelText: 'Nº Ticket',
                    prefixIcon: Icon(Icons.tag, size: 18),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _clienteController,
                  decoration: const InputDecoration(
                    labelText: 'Cliente / Mesa',
                    prefixIcon: Icon(Icons.person, size: 18),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _meseroController,
                  decoration: const InputDecoration(
                    labelText: 'Mesero / Cajero',
                    prefixIcon: Icon(Icons.badge, size: 18),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Lista de ítems detectados
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PRODUCTOS DETECTADOS EN EL TICKET',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                '${_itemsDetectados.length} ítems',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_itemsDetectados.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'No se detectaron productos legibles en la imagen.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _itemsDetectados.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _itemsDetectados[index];
                return _buildItemRow(index, item);
              },
            ),
        ],
      ),
    );
  }

  /// Tarjeta de cada ítem detectado con controles de cantidad y mapeo de producto
  Widget _buildItemRow(int index, ItemTicketEscaneado item) {
    final bool vinculado = item.estaVinculado;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: vinculado
            ? AppTheme.surfaceVariant
            : AppTheme.errorCoral.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: vinculado ? AppTheme.borderLight : AppTheme.errorCoral,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Texto original detectado en el ticket
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Ticket: "${item.nombreDetectado}"',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const Spacer(),
              // Botón eliminar ítem
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppTheme.errorCoral,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                tooltip: 'Eliminar ítem',
                onPressed: () => _eliminarItem(index),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Selector del producto de catálogo
          Row(
            children: [
              Expanded(
                child: vinculado
                    ? DropdownButtonHideUnderline(
                        child: DropdownButton<ProductoBarra>(
                          isExpanded: true,
                          value: item.productoSugerido,
                          dropdownColor: AppTheme.surfaceVariant,
                          items: widget.catalogoProductos.map((p) {
                            return DropdownMenuItem<ProductoBarra>(
                              value: p,
                              child: Text(
                                '${p.nombre} (REF. ${p.precioVenta.toStringAsFixed(2)})',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (p) => _cambiarProducto(index, p),
                        ),
                      )
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<ProductoBarra>(
                          isExpanded: true,
                          hint: const Text(
                            '⚠ Seleccionar producto del catálogo...',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.errorCoral,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          dropdownColor: AppTheme.surfaceVariant,
                          items: widget.catalogoProductos.map((p) {
                            return DropdownMenuItem<ProductoBarra>(
                              value: p,
                              child: Text(
                                '${p.nombre} (REF. ${p.precioVenta.toStringAsFixed(2)})',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (p) => _cambiarProducto(index, p),
                        ),
                      ),
              ),
              const SizedBox(width: 12),

              // Controles de cantidad (- / +)
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 16),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _decrementarCantidad(index),
                    ),
                    Text(
                      item.cantidad % 1 == 0
                          ? item.cantidad.toInt().toString()
                          : item.cantidad.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 16),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _incrementarCantidad(index),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
