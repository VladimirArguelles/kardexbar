import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../services/comandas_service.dart';
import 'formatters.dart';

class ReporteExportHelper {
  /// Genera e imprime o guarda como PDF el Resumen de Turno
  static Future<void> imprimirResumenPdf(ResumenTurnoData data) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final fechaStr = dateFormat.format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Cabecera del documento
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'KARDEXBAR',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.amber800,
                      ),
                    ),
                    pw.Text(
                      'Resumen de Turno y Despacho de Comandas',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Fecha de Operación: ${DateFormat('dd/MM/yyyy').format(data.fecha)}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      'Emitido: $fechaStr',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'TOTAL VENTAS',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        Formatters.currency(data.totalRecaudado),
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(thickness: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 12),

            // Tarjetas KPI resumen
            pw.Row(
              children: [
                _buildKpiPdf('Comandas Procesadas', '${data.totalComandas}', PdfColors.cyan800),
                pw.SizedBox(width: 12),
                _buildKpiPdf('Unidades Despachadas', '${data.totalItemsDespachados.toStringAsFixed(0)} ítems', PdfColors.purple800),
                pw.SizedBox(width: 12),
                _buildKpiPdf('Total Recaudado', Formatters.currency(data.totalRecaudado), PdfColors.green800),
              ],
            ),
            pw.SizedBox(height: 20),

            // Tablas por Categoría (Cócteles, Jugos, Cervezas, Otros)
            ...data.itemsPorCategoria.entries.map((entry) {
              final categoria = entry.key;
              final items = entry.value;

              if (items.isEmpty) {
                return pw.SizedBox.shrink();
              }

              final subtotalCat = items.fold(0.0, (acc, it) => acc + it.totalRecaudado);
              final unidadesCat = items.fold(0.0, (acc, it) => acc + it.cantidadTotal);

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          categoria.toUpperCase(),
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                        ),
                        pw.Text(
                          '${unidadesCat.toStringAsFixed(0)} unds  •  Subtotal: ${Formatters.currency(subtotalCat)}',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.TableHelper.fromTextArray(
                    border: null,
                    headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
                    cellStyle: const pw.TextStyle(fontSize: 9),
                    cellAlignment: pw.Alignment.centerLeft,
                    cellAlignments: {
                      0: pw.Alignment.centerLeft,
                      1: pw.Alignment.centerRight,
                      2: pw.Alignment.centerRight,
                      3: pw.Alignment.centerRight,
                    },
                    headers: ['Producto / Carta', 'Cantidad', 'Precio Unit.', 'Total Recaudado'],
                    data: items.map((it) {
                      return [
                        it.productoNombre,
                        it.cantidadTotal.toStringAsFixed(0),
                        Formatters.currency(it.precioUnitario),
                        Formatters.currency(it.totalRecaudado),
                      ];
                    }).toList(),
                  ),
                  pw.SizedBox(height: 16),
                ],
              );
            }),

            pw.SizedBox(height: 24),
            pw.Divider(thickness: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 32),

            // Firmas de conformidad
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Container(width: 180, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 6),
                    pw.Text('Bartender / Responsable de Barra', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Container(width: 180, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 6),
                    pw.Text('Caja / Supervisor de Turno', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Resumen_Turno_KardexBar_${DateFormat('yyyyMMdd').format(data.fecha)}.pdf',
    );
  }

  static pw.Widget _buildKpiPdf(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color, width: 1),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  /// Genera y descarga el archivo CSV/Excel del Resumen de Turno
  static Future<void> exportarResumenCsv(ResumenTurnoData data) async {
    final StringBuffer csv = StringBuffer();

    // UTF-8 BOM para que Excel en Windows reconozca tildes y caracteres especiales automáticamente
    csv.write('\uFEFF');

    // Encabezado del reporte
    csv.writeln('KARDEXBAR - RESUMEN DE TURNO');
    csv.writeln('Fecha de Operación;${DateFormat('dd/MM/yyyy').format(data.fecha)}');
    csv.writeln('Total Comandas;${data.totalComandas}');
    csv.writeln('Total Recaudado;${data.totalRecaudado.toStringAsFixed(2)}');
    csv.writeln('Total Items Despachados;${data.totalItemsDespachados.toStringAsFixed(0)}');
    csv.writeln('');

    // Encabezado de columnas
    csv.writeln('Categoria;Producto;Cantidad_Despachada;Precio_Unitario;Total_Recaudado');

    for (final entry in data.itemsPorCategoria.entries) {
      final categoria = entry.key;
      for (final it in entry.value) {
        final nombreEscapado = '"${it.productoNombre.replaceAll('"', '""')}"';
        csv.writeln(
          '$categoria;$nombreEscapado;${it.cantidadTotal.toStringAsFixed(0)};${it.precioUnitario.toStringAsFixed(2)};${it.totalRecaudado.toStringAsFixed(2)}',
        );
      }
    }

    final Uint8List bytes = Uint8List.fromList(utf8.encode(csv.toString()));
    final filename = 'Resumen_Turno_KardexBar_${DateFormat('yyyyMMdd').format(data.fecha)}.csv';

    await Printing.sharePdf(
      bytes: bytes,
      filename: filename,
    );
  }
}
