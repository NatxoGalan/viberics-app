import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'print_service.dart';

/// Implementación web: genera PDF y usa el diálogo del sistema.
class WebPrintService extends PrintService {
  @override
  Future<void> printTicket({
    required BuildContext context,
    required String tableName,
    required List<MapEntry<String, dynamic>> items,
    required double total,
    required String userEmail,
  }) async {
    final pdf = pw.Document();
    final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final int totalItems = items.fold<int>(
      0,
      (acc, entry) => acc + ((entry.value['cantidad'] as num?)?.toInt() ?? 0),
    );

    const double ticketWidth = 80 * PdfPageFormat.mm;
    final double ticketHeightMm = 150 + (items.length * 8.0);

    final pageFormat = PdfPageFormat(
      ticketWidth,
      ticketHeightMm * PdfPageFormat.mm,
      marginAll: 6 * PdfPageFormat.mm,
    );

    pw.Widget ticketRow(String left, String right,
        {pw.TextStyle? leftStyle, pw.TextStyle? rightStyle}) {
      final defaultStyle = const pw.TextStyle(fontSize: 8);
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(left, style: leftStyle ?? defaultStyle),
          pw.Text(right, style: rightStyle ?? defaultStyle),
        ],
      );
    }

    pw.Widget dottedLine() {
      return pw.Container(
        margin: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Text(
          '- ' * 30,
          style: const pw.TextStyle(fontSize: 6),
          textAlign: pw.TextAlign.center,
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(6),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  '\u00b7 vib\u00e8rics \u00b7',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text('VIB\u00c8RICS O.E.',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Center(
                child: pw.Text('PLAZA MAYOR, 13',
                    style: const pw.TextStyle(fontSize: 7)),
              ),
              pw.Center(
                child: pw.Text('46450 BENIFAIO',
                    style: const pw.TextStyle(fontSize: 7)),
              ),
              pw.Center(
                child: pw.Text('Cif. E-55437081',
                    style: const pw.TextStyle(fontSize: 7)),
              ),
              pw.Center(
                child: pw.Text('Tlf. 699 620 662',
                    style: const pw.TextStyle(fontSize: 7)),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text('Factura proforma',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.5),
                ),
                child: pw.Column(
                  children: [
                    ticketRow('Mesa: $tableName', now),
                    pw.SizedBox(height: 2),
                    ticketRow('Atendido por:', userEmail),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(width: 0.5),
                    bottom: pw.BorderSide(width: 0.5),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 4,
                      child: pw.Text('Producto',
                          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.SizedBox(
                      width: 25,
                      child: pw.Text('Ud.',
                          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center),
                    ),
                    pw.SizedBox(
                      width: 35,
                      child: pw.Text('P/ud',
                          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right),
                    ),
                    pw.SizedBox(
                      width: 40,
                      child: pw.Text('\u20ac',
                          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
              ),
              ...items.map((entry) {
                final name = entry.key;
                final data = entry.value;
                final price = (data['precio'] as num?)?.toDouble() ?? 0.0;
                final qty = (data['cantidad'] as num?)?.toInt() ?? 0;
                final subtotal = price * qty;

                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 4,
                        child: pw.Text(name,
                            style: const pw.TextStyle(fontSize: 7)),
                      ),
                      pw.SizedBox(
                        width: 25,
                        child: pw.Text('$qty',
                            style: const pw.TextStyle(fontSize: 7),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.SizedBox(
                        width: 35,
                        child: pw.Text(price.toStringAsFixed(2),
                            style: const pw.TextStyle(fontSize: 7),
                            textAlign: pw.TextAlign.right),
                      ),
                      pw.SizedBox(
                        width: 40,
                        child: pw.Text(subtotal.toStringAsFixed(2),
                            style: const pw.TextStyle(fontSize: 7),
                            textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                );
              }),
              dottedLine(),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(width: 0.5),
                    bottom: pw.BorderSide(width: 0.5),
                  ),
                ),
                child: pw.Column(
                  children: [
                    ticketRow('N. Ops', '\u20ac',
                        leftStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                        rightStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    ticketRow(
                      'Total:       $totalItems',
                      total.toStringAsFixed(2),
                      leftStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      rightStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(width: 0.5),
                    bottom: pw.BorderSide(width: 0.5),
                  ),
                ),
                child: pw.Column(
                  children: [
                    ticketRow('M\u00e9todo de pago', '\u20ac',
                        leftStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                        rightStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    ticketRow('Cash', total.toStringAsFixed(2)),
                    ticketRow('Entregado:', total.toStringAsFixed(2)),
                    ticketRow('Cambio:', '0,00',
                        leftStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                        rightStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Atendido por: $userEmail',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'GRACIAS POR SU VISITA',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 8),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Ticket_$tableName',
    );
  }
}
