import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../theme/app_theme.dart';

/// Datos estructurados para imprimir o exportar mediante [ExportPrintWidget]
class ReporteExportData {
  final String titulo;
  final String subtitulo;
  final DateTime fecha;
  final Map<String, String> resumenKpis;
  final List<String> columnasTabla;
  final List<List<String>> filasTabla;
  final String? notasPie;

  ReporteExportData({
    required this.titulo,
    this.subtitulo = 'Reporte Oficial KardexBar',
    required this.fecha,
    this.resumenKpis = const {},
    required this.columnasTabla,
    required this.filasTabla,
    this.notasPie,
  });
}

/// Widget reutilizable para Imprimir (PDF / POS) y Guardar/Compartir Excel (.csv/.xlsx).
class ExportPrintWidget extends StatelessWidget {
  final ReporteExportData data;
  final String? buttonLabelPrint;
  final String? buttonLabelExport;
  final bool isCompact;

  const ExportPrintWidget({
    super.key,
    required this.data,
    this.buttonLabelPrint = 'Imprimir (PDF / POS)',
    this.buttonLabelExport = 'Exportar (Excel / CSV)',
    this.isCompact = false,
  });

  /// Muestra un modal emergente rápido de impresión y exportación
  static Future<void> showModal(
    BuildContext context, {
    required ReporteExportData data,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.print_outlined,
                  color: AppTheme.primaryAmber,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    data.titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Seleccione la opción deseada para emitir o archivar el reporte del turno.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            ExportPrintWidget(data: data),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// Genera y envía a imprimir o previsualizar el PDF (formato ticket/reporte)
  static Future<void> ejecutarImpresionPdf(ReporteExportData data) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final fechaStr = dateFormat.format(data.fecha);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Cabecera Oficial
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
                      data.titulo,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      data.subtitulo,
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      'Fecha de Operación: $fechaStr',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'SEDE PRINCIPAL',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        'Control Barra',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.amber900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(thickness: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 12),

            // Resumen de KPIs si existen
            if (data.resumenKpis.isNotEmpty) ...[
              pw.Wrap(
                spacing: 12,
                runSpacing: 8,
                children: data.resumenKpis.entries.map((e) {
                  return pw.Container(
                    width: 150,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          e.key,
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          e.value,
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              pw.SizedBox(height: 16),
            ],

            // Tabla de datos
            pw.TableHelper.fromTextArray(
              headers: data.columnasTabla,
              data: data.filasTabla,
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                ),
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 4,
              ),
            ),

            if (data.notasPie != null) ...[
              pw.SizedBox(height: 16),
              pw.Text(
                'Observaciones: ${data.notasPie}',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ],

            pw.SizedBox(height: 36),
            pw.Divider(thickness: 0.5, color: PdfColors.grey400),
            pw.SizedBox(height: 24),

            // Firmas de conformidad
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Container(width: 160, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Bartender Operativo',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Container(width: 160, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Supervisor / Administración',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    final cleanName = data.titulo.replaceAll(RegExp(r'\s+'), '_');
    final filename =
        '${cleanName}_${DateFormat('yyyyMMdd_HHmm').format(data.fecha)}.pdf';

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: filename,
    );
  }

  /// Genera y descarga/comparte el archivo Excel / CSV con UTF-8 BOM
  static Future<void> ejecutarExportacionCsv(ReporteExportData data) async {
    final StringBuffer csv = StringBuffer();

    // UTF-8 BOM para que Microsoft Excel en Windows reconozca caracteres y tildes automáticamente
    csv.write('\uFEFF');

    csv.writeln('KARDEXBAR - SISTEMA DE CONTROL DE BARRA');
    csv.writeln('${data.titulo};${data.subtitulo}');
    csv.writeln(
      'Fecha de Emisión;${DateFormat('dd/MM/yyyy HH:mm').format(data.fecha)}',
    );
    csv.writeln('');

    if (data.resumenKpis.isNotEmpty) {
      csv.writeln('RESUMEN DE INDICADORES');
      for (final entry in data.resumenKpis.entries) {
        csv.writeln('${entry.key};${entry.value}');
      }
      csv.writeln('');
    }

    // Cabecera de columnas
    csv.writeln(data.columnasTabla.join(';'));

    // Filas
    for (final fila in data.filasTabla) {
      final filaFormateada = fila
          .map((col) {
            final colStr = col.replaceAll('"', '""');
            return '"$colStr"';
          })
          .join(';');
      csv.writeln(filaFormateada);
    }

    if (data.notasPie != null) {
      csv.writeln('');
      csv.writeln(
        'Notas / Observaciones;"${data.notasPie!.replaceAll('"', '""')}"',
      );
    }

    final Uint8List bytes = Uint8List.fromList(utf8.encode(csv.toString()));
    final cleanName = data.titulo.replaceAll(RegExp(r'\s+'), '_');
    final filename =
        '${cleanName}_${DateFormat('yyyyMMdd_HHmm').format(data.fecha)}.csv';

    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: buttonLabelPrint,
            icon: const Icon(Icons.print, color: AppTheme.primaryAmber),
            onPressed: () => ejecutarImpresionPdf(data),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: buttonLabelExport,
            icon: const Icon(
              Icons.file_download,
              color: AppTheme.secondaryCyan,
            ),
            onPressed: () => ejecutarExportacionCsv(data),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        final printBtn = ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryAmber,
            foregroundColor: AppTheme.background,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          ),
          icon: const Icon(Icons.print, size: 20),
          label: Flexible(
            child: Text(
              buttonLabelPrint ?? 'Imprimir (PDF)',
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          onPressed: () => ejecutarImpresionPdf(data),
        );

        final exportBtn = OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.secondaryCyan,
            side: const BorderSide(color: AppTheme.secondaryCyan, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          ),
          icon: const Icon(Icons.table_chart_outlined, size: 20),
          label: Flexible(
            child: Text(
              buttonLabelExport ?? 'Excel / CSV',
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          onPressed: () => ejecutarExportacionCsv(data),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [printBtn, const SizedBox(height: 10), exportBtn],
          );
        }

        return Row(
          children: [
            Expanded(child: printBtn),
            const SizedBox(width: 12),
            Expanded(child: exportBtn),
          ],
        );
      },
    );
  }
}
