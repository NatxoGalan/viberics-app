import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'select_product_screen.dart';

class TableDetailScreen extends StatefulWidget {
  final String tableId;
  final String tableName;
  final String userRole;

  const TableDetailScreen({
    super.key,
    required this.tableId,
    required this.tableName,
    required this.userRole,
  });

  @override
  State<TableDetailScreen> createState() => _TableDetailScreenState();
}

class _TableDetailScreenState extends State<TableDetailScreen> {
  late Stream<DocumentSnapshot> _tableStream;

  @override
  void initState() {
    super.initState();
    _tableStream = FirebaseFirestore.instance
        .collection('mesas')
        .doc(widget.tableId)
        .snapshots();
  }

  // --- NUEVA FUNCIÓN: CAMBIAR NOMBRE DE LA MESA ---
  Future<void> _editTableName(BuildContext context, String currentName) async {
    final TextEditingController nameController = TextEditingController(text: currentName);
    
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cambiar nombre de la mesa'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Nuevo nombre'),
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final newName = nameController.text.trim();
      if (newName.isNotEmpty && newName != currentName) {
        try {
          await FirebaseFirestore.instance.collection('mesas').doc(widget.tableId).update({
            'nombre': newName,
          });
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Nombre actualizado a "$newName"')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al actualizar: $e')),
            );
          }
        }
      }
    }
  }

  Future<void> _updateItem(String itemName, {int? quantityChange, bool deleteItem = false}) async {
    final firestore = FirebaseFirestore.instance;
    final tableRef = firestore.collection('mesas').doc(widget.tableId);
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'Desconocido';
    String actionLog;

    await firestore.runTransaction((transaction) async {
      final tableSnapshot = await transaction.get(tableRef);
      if (!tableSnapshot.exists) throw Exception("La mesa no existe!");

      final tableData = tableSnapshot.data() as Map<String, dynamic>;
      final Map<String, dynamic> items = Map<String, dynamic>.from(tableData['items'] ?? {});

      if (items.containsKey(itemName)) {
        if (deleteItem) {
          actionLog = 'Eliminó de la comanda';
          items.remove(itemName);
        } else if (quantityChange != null) {
          final currentQuantity = items[itemName]['cantidad'] ?? 0;
          items[itemName]['cantidad'] = currentQuantity + quantityChange;
          actionLog = quantityChange > 0 ? 'Añadió 1 unidad' : 'Quitó 1 unidad';
          if (items[itemName]['cantidad'] <= 0) {
            items.remove(itemName);
            actionLog = 'Eliminó de la comanda';
          }
        } else {
          return; 
        }

        double newTotal = 0.0;
        items.forEach((key, value) {
          final itemPrice = (value['precio'] as num?)?.toDouble() ?? 0.0;
          final itemQuantity = (value['cantidad'] as num?)?.toInt() ?? 0;
          newTotal += itemPrice * itemQuantity;
        });

        final logEntry = {
          'accion': actionLog,
          'producto': itemName,
          'camarero': userEmail,
          'fecha': FieldValue.serverTimestamp(),
        };
        transaction.set(tableRef.collection('log').doc(), logEntry);

        transaction.update(tableRef, {'items': items, 'total': newTotal});
      }
    });
  }

  // --- ESTABLECER CANTIDAD ABSOLUTA ---
  Future<void> _setItemQuantity(String itemName, int newQuantity) async {
    final firestore = FirebaseFirestore.instance;
    final tableRef = firestore.collection('mesas').doc(widget.tableId);
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'Desconocido';

    await firestore.runTransaction((transaction) async {
      final tableSnapshot = await transaction.get(tableRef);
      if (!tableSnapshot.exists) throw Exception("La mesa no existe!");

      final tableData = tableSnapshot.data() as Map<String, dynamic>;
      final Map<String, dynamic> items = Map<String, dynamic>.from(tableData['items'] ?? {});

      String actionLog;
      if (!items.containsKey(itemName)) return;

      if (newQuantity <= 0) {
        items.remove(itemName);
        actionLog = 'Eliminó de la comanda';
      } else {
        items[itemName]['cantidad'] = newQuantity;
        actionLog = 'Cambió cantidad a $newQuantity';
      }

      double newTotal = 0.0;
      items.forEach((key, value) {
        final itemPrice = (value['precio'] as num?)?.toDouble() ?? 0.0;
        final itemQuantity = (value['cantidad'] as num?)?.toInt() ?? 0;
        newTotal += itemPrice * itemQuantity;
      });

      final logEntry = {
        'accion': actionLog,
        'producto': itemName,
        'camarero': userEmail,
        'fecha': FieldValue.serverTimestamp(),
      };
      transaction.set(tableRef.collection('log').doc(), logEntry);
      transaction.update(tableRef, {'items': items, 'total': newTotal});
    });
  }

  // --- DIÁLOGO PARA ESCRIBIR CANTIDAD ---
  Future<void> _showQuantityDialog(String itemName, int currentQuantity) async {
    final TextEditingController controller = TextEditingController(text: '$currentQuantity');

    final int? newQuantity = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Cantidad de $itemName'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nueva cantidad',
              hintText: 'Ej: 5',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              final parsed = int.tryParse(value);
              Navigator.of(context).pop(parsed);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text);
                Navigator.of(context).pop(parsed);
              },
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );

    if (newQuantity != null && newQuantity != currentQuantity) {
      await _setItemQuantity(itemName, newQuantity);
    }
  }

  // --- GENERAR PDF ESTILO TICKET TÉRMICO ---
  Future<void> _generateAndPrintPdf(
    String tableName,
    List<MapEntry<String, dynamic>> items,
    double total,
  ) async {
    final pdf = pw.Document();
    final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final int totalItems = items.fold<int>(
      0,
      (acc, entry) => acc + ((entry.value['cantidad'] as num?)?.toInt() ?? 0),
    );

    // Formato de ticket térmico: 80mm de ancho, altura variable
    const double ticketWidth = 80 * PdfPageFormat.mm;

    // Calcular la altura necesaria en mm basada en el número de items
    final double ticketHeightMm = 150 + (items.length * 8.0);

    final pageFormat = PdfPageFormat(
      ticketWidth,
      ticketHeightMm * PdfPageFormat.mm,
      marginAll: 6 * PdfPageFormat.mm,
    );

    // Helper para crear línea de texto alineada (izq - der)
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

    // Helper para línea de puntos separadora
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
              // ===== CABECERA: LOGO VIBÈRICS =====
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

              // ===== DATOS DEL NEGOCIO =====
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

              // ===== DATOS DE LA MESA Y FECHA (en recuadro) =====
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
                    ticketRow(
                      'Atendido por:',
                      'Marta',
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 6),

              // ===== CABECERA DE PRODUCTOS =====
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

              // ===== LISTA DE PRODUCTOS =====
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

              // ===== TOTAL =====
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

              // ===== MÉTODO DE PAGO =====
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

              // ===== PIE DE TICKET =====
              pw.Center(
                child: pw.Text(
                  'Atendido por: Marta',
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

  Future<void> _updateItemPrice(BuildContext context, String itemName) async {
    final firestore = FirebaseFirestore.instance;
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'Desconocido';

    try {
      final productQuery = await firestore
          .collection('productos')
          .where('nombre', isEqualTo: itemName)
          .limit(1)
          .get();

      if (productQuery.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"$itemName" ya no se encuentra en la carta.')),
          );
        }
        return;
      }

      final newPrice = (productQuery.docs.first.data()['precio'] as num).toDouble();

      await firestore.runTransaction((transaction) async {
        final tableRef = firestore.collection('mesas').doc(widget.tableId);
        final tableSnapshot = await transaction.get(tableRef);
        if (!tableSnapshot.exists) throw Exception("La mesa no existe!");

        final tableData = tableSnapshot.data() as Map<String, dynamic>;
        final Map<String, dynamic> items = Map<String, dynamic>.from(tableData['items'] ?? {});

        if (items.containsKey(itemName)) {
          items[itemName]['precio'] = newPrice;
        }

        double newTotal = 0.0;
        items.forEach((key, value) {
          final itemPrice = (value['precio'] as num?)?.toDouble() ?? 0.0;
          final itemQuantity = (value['cantidad'] as num?)?.toInt() ?? 0;
          newTotal += itemPrice * itemQuantity;
        });
        
        final logEntry = {
          'accion': 'Actualizó precio',
          'producto': itemName,
          'camarero': userEmail,
          'fecha': FieldValue.serverTimestamp(),
        };
        transaction.set(tableRef.collection('log').doc(), logEntry);

        transaction.update(tableRef, {'items': items, 'total': newTotal});
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Precio de "$itemName" actualizado.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e')),
        );
      }
    }
  }
  
  Future<void> _emptyTable(BuildContext context) async {
    final bool? confirmEmpty = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Vaciado'),
          content: const Text(
              '¿Estás seguro? Se borrarán todos los productos y el historial de actividad. La mesa se marcará como Libre.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Vaciar Mesa', style: TextStyle(color: Colors.orange)),
            ),
          ],
        );
      },
    );

    if (confirmEmpty == true) {
      try {
        final firestore = FirebaseFirestore.instance;
        final tableRef = firestore.collection('mesas').doc(widget.tableId);
        final logCollectionRef = tableRef.collection('log');

        final batch = firestore.batch();

        final logSnapshot = await logCollectionRef.get();
        for (final doc in logSnapshot.docs) {
          batch.delete(doc.reference);
        }

        batch.update(tableRef, {
          'items': {},
          'total': 0.0,
          'estado': 'Libre',
        });

        await batch.commit();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Mesa vaciada correctamente.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al vaciar la mesa: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteTable(BuildContext context) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: const Text(
              '¿Estás seguro de que quieres eliminar esta mesa? Se borrará la mesa, su comanda y todo su historial de forma permanente.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar Mesa', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        final firestore = FirebaseFirestore.instance;
        final tableRef = firestore.collection('mesas').doc(widget.tableId);
        final logCollectionRef = tableRef.collection('log');

        final logSnapshot = await logCollectionRef.get();
        final batch = firestore.batch();
        for (final doc in logSnapshot.docs) {
          batch.delete(doc.reference);
        }

        batch.delete(tableRef);

        await batch.commit();

        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mesa eliminada correctamente.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar la mesa: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _tableStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
              appBar: AppBar(title: Text('Comanda: ${widget.tableName}')),
              body: const Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
              appBar: AppBar(title: Text('Comanda: ${widget.tableName}')),
              body: const Center(child: Text('Esta mesa ya no existe.')));
        }

        final tableData = snapshot.data!.data() as Map<String, dynamic>;
        
        // --- AQUÍ HACEMOS QUE EL NOMBRE SEA REACTIVO ---
        final String currentTableName = tableData['nombre'] ?? widget.tableName;

        final dynamic rawItems = tableData['items'];
        final Map<String, dynamic> items = {};

        if (rawItems is Map) {
          items.addAll(Map<String, dynamic>.from(rawItems));
        } else if (rawItems is List) {
          for (var item in rawItems) {
            if (item is Map) {
              final String? name = item['nombre'];
              final num? price = item['precio'];
              if (name != null && price != null) {
                if (items.containsKey(name)) {
                  items[name]['cantidad'] =
                      (items[name]['cantidad'] ?? 0) + 1;
                } else {
                  items[name] = {'precio': price, 'cantidad': 1};
                }
              }
            }
          }
        }

        final double total = (tableData['total'] as num?)?.toDouble() ?? 0.0;
        final groupedItems = items.entries.toList();

        return Scaffold(
          appBar: AppBar(
            title: Text('Comanda: $currentTableName'),
            actions: [
              // --- BOTÓN DE EDITAR NOMBRE ---
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editTableName(context, currentTableName),
                tooltip: 'Cambiar Nombre',
              ),
              // --- BOTÓN DE DESCARGAR PDF (solo jefe) ---
              if (items.isNotEmpty && widget.userRole == 'jefe')
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.blue),
                  onPressed: () => _generateAndPrintPdf(currentTableName, groupedItems, total),
                  tooltip: 'Descargar PDF',
                ),
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined, color: Colors.orange),
                onPressed: () => _emptyTable(context),
                tooltip: 'Vaciar Mesa',
              ),
              IconButton(
                icon: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                onPressed: () => _deleteTable(context),
                tooltip: 'Eliminar Mesa',
              ),
            ],
          ),
          body: items.isEmpty
              ? const Center(child: Text('No hay productos en esta comanda.'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: groupedItems.length,
                  itemBuilder: (context, index) {
                    final itemEntry = groupedItems[index];
                    final itemName = itemEntry.key;
                    final itemData = itemEntry.value;
                    final itemPrice =
                        (itemData['precio'] as num?)?.toDouble() ?? 0.0;
                    final itemQuantity =
                        (itemData['cantidad'] as num?)?.toInt() ?? 0;
                    final subtotal = itemPrice * itemQuantity;
                    final bool showPrices = widget.userRole == 'jefe';

                    return ListTile(
                      title: Text(itemName),
                      subtitle: showPrices
                          ? Text('${itemPrice.toStringAsFixed(2)} € / ud.')
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade700),
                            onPressed: () => _updateItem(itemName, quantityChange: -1),
                            tooltip: 'Quitar uno',
                          ),
                          // --- CANTIDAD PULSABLE PARA EDITAR POR TECLADO ---
                          InkWell(
                            onTap: () => _showQuantityDialog(itemName, itemQuantity),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade400),
                              ),
                              child: Text(
                                '$itemQuantity',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add_circle_outline, color: Colors.green.shade700),
                            onPressed: () => _updateItem(itemName, quantityChange: 1),
                            tooltip: 'Añadir uno',
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'delete') {
                                _updateItem(itemName, deleteItem: true);
                              } else if (value == 'update_price') {
                                _updateItemPrice(context, itemName);
                              }
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: Text('Eliminar de la comanda'),
                              ),
                              const PopupMenuItem<String>(
                                value: 'update_price',
                                child: Text('Actualizar precio'),
                              ),
                            ],
                            icon: Icon(Icons.more_vert, color: Colors.grey.shade700),
                            tooltip: 'Más opciones',
                          ),
                          if (showPrices)
                          SizedBox(
                            width: 80,
                            child: Text(
                              '${subtotal.toStringAsFixed(2)} €',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SelectProductScreen(
                    tableId: widget.tableId,
                    userRole: widget.userRole,
                  ),
                ),
              );
            },
            tooltip: 'Añadir Producto',
            child: const Icon(Icons.add_shopping_cart),
          ),
          // Solo mostrar el total si el usuario es jefe
          bottomNavigationBar: widget.userRole == 'jefe'
              ? BottomAppBar(
                  elevation: 8.0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total:',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          '${total.toStringAsFixed(2)} €',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}