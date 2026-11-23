import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Modelo de ítem para el ticket POS de despacho y cuenta
class TicketItemData {
  final double cantidad;
  final String nombreProducto;
  final double? precioUnitario;

  const TicketItemData({
    required this.cantidad,
    required this.nombreProducto,
    this.precioUnitario,
  });
}

/// Datos estructurados para imprimir el ticket de producción/despacho idéntico a la imagen POS oficial
class TicketPosData {
  final String ordenArea;
  final String cliente;
  final String mesero;
  final DateTime fecha;
  final int ronda;
  final String numeroOrden;
  final List<TicketItemData> items;
  final String? notasCoordinacion;
  final double? total;

  const TicketPosData({
    this.ordenArea = 'BARRA',
    required this.cliente,
    this.mesero = 'ILARIO MEDINA',
    required this.fecha,
    this.ronda = 1,
    required this.numeroOrden,
    required this.items,
    this.notasCoordinacion,
    this.total,
  });
}

/// Generador del Ticket POS Térmico (formato de imagen adjunta con QR y Courier tipográfico)
class TicketPosBarra {
  /// Imprime o previsualiza el ticket en formato térmico de rollo POS (80mm / 72mm imprimible)
  static Future<void> imprimirTicket(TicketPosData data) async {
    final pdf = pw.Document();
    final dateFormatted = DateFormat('yy/MM/dd  hh:mm a').format(data.fecha);

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          72 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 3 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              // === ORDEN: BARRA ===
              // ===
              pw.Text(
                '=== ORDEN:  ${data.ordenArea.toUpperCase()} ===',
                style: pw.TextStyle(
                  font: pw.Font.courierBold(),
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                '===',
                style: pw.TextStyle(
                  font: pw.Font.courierBold(),
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1, color: PdfColors.black),
              pw.SizedBox(height: 4),

              // JESUS RÍOS (Nombre de cliente en negrita mayúsculas)
              pw.Text(
                data.cliente.toUpperCase(),
                style: pw.TextStyle(
                  font: pw.Font.courierBold(),
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1, color: PdfColors.black),
              pw.SizedBox(height: 6),

              // Mesero:   ILARIO MEDINA
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Mesero:',
                    style: pw.TextStyle(font: pw.Font.courier(), fontSize: 10),
                  ),
                  pw.Text(
                    data.mesero.toUpperCase(),
                    style: pw.TextStyle(
                      font: pw.Font.courierBold(),
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 3),

              // 22/11/26  05:49 PM
              pw.Text(
                dateFormatted,
                style: pw.TextStyle(font: pw.Font.courier(), fontSize: 10),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 3),

              // [Ronda 1]
              pw.Text(
                '[Ronda ${data.ronda}]',
                style: pw.TextStyle(
                  font: pw.Font.courierBold(),
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 3),

              // No. Orden:     11E6D68B
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'No. Orden:',
                    style: pw.TextStyle(font: pw.Font.courier(), fontSize: 10),
                  ),
                  pw.Text(
                    data.numeroOrden.toUpperCase(),
                    style: pw.TextStyle(
                      font: pw.Font.courierBold(),
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1, color: PdfColors.black),
              pw.SizedBox(height: 6),

              // Lista de productos: 2X   CERVEZA ZULIA/POLAR
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: data.items.map((item) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 3),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '${item.cantidad.toStringAsFixed(0)}X   ',
                          style: pw.TextStyle(
                            font: pw.Font.courierBold(),
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            item.nombreProducto.toUpperCase(),
                            style: pw.TextStyle(
                              font: pw.Font.courierBold(),
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1, color: PdfColors.black),

              // COORDINACION CON OTRAS AREAS (si existen notas)
              if (data.notasCoordinacion != null &&
                  data.notasCoordinacion!.trim().isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    'COORDINACION CON OTRAS AREAS:',
                    style: pw.TextStyle(
                      font: pw.Font.courierBold(),
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    data.notasCoordinacion!.trim(),
                    style: pw.TextStyle(font: pw.Font.courier(), fontSize: 9),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 1, color: PdfColors.black),
              ],

              // Total si es ticket de cuenta/cierre
              if (data.total != null && data.total! > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL A PAGAR:',
                      style: pw.TextStyle(
                        font: pw.Font.courierBold(),
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '\$${data.total!.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        font: pw.Font.courierBold(),
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 1, color: PdfColors.black),
              ],

              pw.SizedBox(height: 8),

              // CÓDIGO QR CENTRADO
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: data.numeroOrden,
                  width: 75,
                  height: 75,
                ),
              ),
              pw.SizedBox(height: 6),

              // [ #11E6D68B ]
              pw.Center(
                child: pw.Text(
                  '[ #${data.numeroOrden.toUpperCase()} ]',
                  style: pw.TextStyle(
                    font: pw.Font.courierBold(),
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );

    final cleanTicket = data.numeroOrden.replaceAll(
      RegExp(r'[^a-zA-Z0-9]'),
      '',
    );
    final filename =
        'Ticket_${data.cliente.replaceAll(' ', '_')}_$cleanTicket.pdf';

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: filename,
    );
  }
}
