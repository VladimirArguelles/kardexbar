import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../models/comanda_model.dart';
import '../models/ticket_escaneado_model.dart';

/// Servicio para escaneo inteligente de comandas y tickets de caja mediante visión artificial
class TicketScannerService {
  final _client = SupabaseConfig.client;
  final ImagePicker _picker = ImagePicker();

  /// Captura una fotografía usando la cámara del dispositivo (móvil o web)
  Future<XFile?> capturarFotoCamara() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );
    } catch (e) {
      debugPrint('Error al capturar foto desde cámara: $e');
      rethrow;
    }
  }

  /// Selecciona una imagen desde la galería o explorador de archivos
  Future<XFile?> seleccionarFotoGaleria() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );
    } catch (e) {
      debugPrint('Error al seleccionar imagen desde galería: $e');
      rethrow;
    }
  }

  /// Envía la imagen y el catálogo de productos a la Edge Function `parse-comanda-ticket`
  /// Retorna un `TicketEscaneadoResult` con los datos estructurados.
  Future<TicketEscaneadoResult> escanearTicket({
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
    required List<ProductoBarra> productosDisponibles,
  }) async {
    if (imageBytes.isEmpty) {
      throw Exception('Los bytes de la imagen están vacíos.');
    }

    final base64Image = base64Encode(imageBytes);

    final productosPayload = productosDisponibles
        .map(
          (p) => {
            'id': p.id,
            'nombre': p.nombre,
            'precio': p.precioVenta,
            'categoria': p.categoria,
          },
        )
        .toList();

    final payload = {
      'imageBase64': base64Image,
      'mimeType': mimeType,
      'productos': productosPayload,
    };

    FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'parse-comanda-ticket',
        body: payload,
      );
    } on FunctionException catch (fe) {
      String msg = fe.details?.toString() ?? 'Error en servicio de escaneo';
      if (fe.details is Map && fe.details['error'] != null) {
        msg = fe.details['error'].toString();
      } else if (fe.details is String) {
        try {
          final parsed = jsonDecode(fe.details as String);
          if (parsed is Map && parsed['error'] != null) {
            msg = parsed['error'].toString();
          }
        } catch (_) {}
      }
      throw Exception(msg);
    }

    if (response.status != 200) {
      final errorMsg = response.data is Map && response.data['error'] != null
          ? response.data['error'].toString()
          : 'Error en Edge Function (${response.status})';
      throw Exception(errorMsg);
    }

    final dynamic data = response.data;
    Map<String, dynamic> jsonMap;

    if (data is Map<String, dynamic>) {
      jsonMap = data;
    } else if (data is Map) {
      jsonMap = Map<String, dynamic>.from(data);
    } else if (data is String) {
      jsonMap = jsonDecode(data) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Formato de respuesta no reconocido de la Edge Function.',
      );
    }

    return TicketEscaneadoResult.fromJson(
      jsonMap,
      catalogo: productosDisponibles,
    );
  }
}
