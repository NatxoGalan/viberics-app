import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class SavedTicketsScreen extends StatelessWidget {
  const SavedTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('mesas').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error al cargar las mesas: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No hay mesas creadas.'));
        }

        // Filtrar solo mesas que tengan items
        final allTables = snapshot.data!.docs;
        final tablesWithItems = allTables.where((table) {
          final data = table.data() as Map<String, dynamic>;
          final rawItems = data['items'];
          return rawItems is Map && rawItems.isNotEmpty;
        }).toList();

        if (tablesWithItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long,
                    size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'No hay mesas con comanda activa',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cuando una mesa tenga productos,\naparecerá aquí para descargar su ticket.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: tablesWithItems.length,
          itemBuilder: (context, index) {
            final table = tablesWithItems[index];
            final data = table.data() as Map<String, dynamic>;
            return _TableTicketCard(tableData: data);
          },
        );
      },
    );
  }
}

class _TableTicketCard extends StatelessWidget {
  final Map<String, dynamic> tableData;

  const _TableTicketCard({required this.tableData});

  @override
  Widget build(BuildContext context) {
    final String mesa = tableData['nombre'] ?? 'Sin nombre';
    final double total = (tableData['total'] as num?)?.toDouble() ?? 0.0;
    final Map<String, dynamic> items =
        Map<String, dynamic>.from(tableData['items'] ?? {});

    // Contar items por tipo
    int countComida = 0;
    int countBebida = 0;
    int totalItems = 0;
    for (final item in items.values) {
      final tipo = (item['tipo'] as String?) ?? 'comida';
      final cantidad = (item['cantidad'] as num?)?.toInt() ?? 0;
      totalItems += cantidad;
      if (tipo == 'bebida') {
        countBebida += cantidad;
      } else {
        countComida += cantidad;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showTicketDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila superior: nombre mesa
              Row(
                children: [
                  Icon(Icons.table_restaurant,
                      color: Colors.blue.shade700, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mesa,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Resumen de items
              Row(
                children: [
                  if (countComida > 0)
                    _buildChip('🍽 $countComida', Colors.orange.shade100,
                        Colors.orange.shade700),
                  if (countComida > 0 && countBebida > 0)
                    const SizedBox(width: 8),
                  if (countBebida > 0)
                    _buildChip('🥤 $countBebida', Colors.blue.shade100,
                        Colors.blue.shade700),
                  const SizedBox(width: 8),
                  _buildChip('$totalItems uds.', Colors.grey.shade100,
                      Colors.grey.shade700),
                ],
              ),
              const SizedBox(height: 12),

              // Fila inferior: total + botón descargar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${total.toStringAsFixed(2)} €',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _downloadPdf(context),
                    icon: const Icon(Icons.download, size: 20),
                    label: const Text('Guardar PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 12, color: textColor, fontWeight: FontWeight.w500),
      ),
    );
  }

  void _showTicketDetail(BuildContext context) {
    final Map<String, dynamic> items =
        Map<String, dynamic>.from(tableData['items'] ?? {});
    final String mesa = tableData['nombre'] ?? 'Mesa';
    final double total = (tableData['total'] as num?)?.toDouble() ?? 0.0;

    // Separar por tipo
    final comidaItems = <MapEntry<String, dynamic>>[];
    final bebidaItems = <MapEntry<String, dynamic>>[];
    for (final entry in items.entries) {
      final tipo = (entry.value['tipo'] as String?) ?? 'comida';
      if (tipo == 'bebida') {
        bebidaItems.add(entry);
      } else {
        comidaItems.add(entry);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Título
                  Text(
                    'Ticket — $mesa',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Comida
                  if (comidaItems.isNotEmpty) ...[
                    _sectionHeader('🍽  Comida', Colors.orange.shade700),
                    ...comidaItems.map((e) => _itemRow(e)),
                  ],

                  // Bebida
                  if (bebidaItems.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _sectionHeader('🥤  Bebida', Colors.blue.shade700),
                    ...bebidaItems.map((e) => _itemRow(e)),
                  ],

                  const Divider(height: 24),
                  // Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${total.toStringAsFixed(2)} €',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Botón descargar
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _downloadPdf(context);
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Guardar PDF'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _itemRow(MapEntry<String, dynamic> entry) {
    final name = entry.key;
    final itemData = entry.value;
    final price = (itemData['precio'] as num?)?.toDouble() ?? 0.0;
    final qty = (itemData['cantidad'] as num?)?.toInt() ?? 0;
    final subtotal = price * qty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(name, style: const TextStyle(fontSize: 15)),
          ),
          SizedBox(
            width: 30,
            child: Text(
              '×$qty',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              '${price.toStringAsFixed(2)} €',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              '${subtotal.toStringAsFixed(2)} €',
              textAlign: TextAlign.right,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // GENERACIÓN DE PDF INDEPENDIENTE (no usa el servicio de impresión)
  // Genera el PDF y abre el diálogo del sistema para guardar en archivos.
  // ====================================================================
  Future<void> _downloadPdf(BuildContext context) async {
    final Map<String, dynamic> items =
        Map<String, dynamic>.from(tableData['items'] ?? {});
    final String mesa = tableData['nombre'] ?? 'Mesa';
    final double total = (tableData['total'] as num?)?.toDouble() ?? 0.0;
    final String userEmail =
        FirebaseAuth.instance.currentUser?.email ?? 'Camarero';
    final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final int totalItemsCount = items.values.fold<int>(
      0,
      (acc, item) => acc + ((item['cantidad'] as num?)?.toInt() ?? 0),
    );

    // Ordenar: bebidas primero, luego comida
    final sortedItems = items.entries.toList();
    sortedItems.sort((a, b) {
      final tipoA = (a.value['tipo'] as String?) ?? 'comida';
      final tipoB = (b.value['tipo'] as String?) ?? 'comida';
      if (tipoA == 'bebida' && tipoB != 'bebida') return -1;
      if (tipoA != 'bebida' && tipoB == 'bebida') return 1;
      return 0;
    });

    // --- Construir el PDF ---
    final pdf = pw.Document();

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
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
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
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
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
                    ticketRow('Mesa: $mesa', now),
                    pw.SizedBox(height: 2),
                    ticketRow('Atendido por:', userEmail),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 2, vertical: 3),
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
                          style: pw.TextStyle(
                              fontSize: 7,
                              fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.SizedBox(
                      width: 25,
                      child: pw.Text('Ud.',
                          style: pw.TextStyle(
                              fontSize: 7,
                              fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center),
                    ),
                    pw.SizedBox(
                      width: 35,
                      child: pw.Text('P/ud',
                          style: pw.TextStyle(
                              fontSize: 7,
                              fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right),
                    ),
                    pw.SizedBox(
                      width: 40,
                      child: pw.Text('\u20ac',
                          style: pw.TextStyle(
                              fontSize: 7,
                              fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
              ),
              // Lista de productos
              ...sortedItems.map((entry) {
                final name = entry.key;
                final data = entry.value;
                final price =
                    (data['precio'] as num?)?.toDouble() ?? 0.0;
                final qty =
                    (data['cantidad'] as num?)?.toInt() ?? 0;
                final subtotal = price * qty;

                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 2, vertical: 2),
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
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 2, vertical: 3),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(width: 0.5),
                    bottom: pw.BorderSide(width: 0.5),
                  ),
                ),
                child: pw.Column(
                  children: [
                    ticketRow('N. Ops', '\u20ac',
                        leftStyle: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold),
                        rightStyle: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    ticketRow(
                      'Total:       $totalItemsCount',
                      total.toStringAsFixed(2),
                      leftStyle: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold),
                      rightStyle: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 2, vertical: 3),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(width: 0.5),
                    bottom: pw.BorderSide(width: 0.5),
                  ),
                ),
                child: pw.Column(
                  children: [
                    ticketRow('M\u00e9todo de pago', '\u20ac',
                        leftStyle: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold),
                        rightStyle: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    ticketRow('Cash', total.toStringAsFixed(2)),
                    ticketRow('Entregado:', total.toStringAsFixed(2)),
                    ticketRow('Cambio:', '0,00',
                        leftStyle: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold),
                        rightStyle: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold)),
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
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 8),
            ],
          );
        },
      ),
    );

    // Guardar como bytes y abrir diálogo del sistema para guardar en archivos
    final pdfBytes = await pdf.save();

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Ticket_$mesa.pdf',
    );
  }
}
