import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'select_product_screen.dart';
import '../services/print_service.dart';

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
      final Map<String, dynamic> pending = Map<String, dynamic>.from(tableData['pendingPrintItems'] ?? {});

      if (items.containsKey(itemName)) {
        final String tipo = (items[itemName]['tipo'] as String?) ?? 'comida';

        if (deleteItem) {
          actionLog = 'Eliminó de la comanda';
          items.remove(itemName);
          // Eliminar también de pendientes si es comida
          if (tipo == 'comida') pending.remove(itemName);
        } else if (quantityChange != null) {
          final currentQuantity = items[itemName]['cantidad'] ?? 0;
          items[itemName]['cantidad'] = currentQuantity + quantityChange;
          actionLog = quantityChange > 0 ? 'Añadió 1 unidad' : 'Quitó 1 unidad';
          if (items[itemName]['cantidad'] <= 0) {
            items.remove(itemName);
            actionLog = 'Eliminó de la comanda';
            if (tipo == 'comida') pending.remove(itemName);
          } else if (tipo == 'comida' && quantityChange > 0) {
            // Si se añade comida, acumular en pendientes
            pending[itemName] = ((pending[itemName] as num?)?.toInt() ?? 0) + quantityChange;
          } else if (tipo == 'comida' && quantityChange < 0 && pending.containsKey(itemName)) {
            // Si se quita comida y hay pendientes, reducir pendientes
            final pendingQty = ((pending[itemName] as num?)?.toInt() ?? 0) + quantityChange;
            if (pendingQty <= 0) {
              pending.remove(itemName);
            } else {
              pending[itemName] = pendingQty;
            }
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

        transaction.update(tableRef, {'items': items, 'total': newTotal, 'pendingPrintItems': pending});
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
      final Map<String, dynamic> pending = Map<String, dynamic>.from(tableData['pendingPrintItems'] ?? {});

      String actionLog;
      if (!items.containsKey(itemName)) return;

      final String tipo = (items[itemName]['tipo'] as String?) ?? 'comida';
      final int oldQuantity = (items[itemName]['cantidad'] as num?)?.toInt() ?? 0;

      if (newQuantity <= 0) {
        items.remove(itemName);
        actionLog = 'Eliminó de la comanda';
        if (tipo == 'comida') pending.remove(itemName);
      } else {
        items[itemName]['cantidad'] = newQuantity;
        actionLog = 'Cambió cantidad a $newQuantity';
        // Ajustar pendientes proporcionalmente
        if (tipo == 'comida' && pending.containsKey(itemName)) {
          final int diff = newQuantity - oldQuantity;
          final int pendingQty = ((pending[itemName] as num?)?.toInt() ?? 0) + diff;
          if (pendingQty <= 0) {
            pending.remove(itemName);
          } else {
            pending[itemName] = pendingQty;
          }
        }
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
      transaction.update(tableRef, {'items': items, 'total': newTotal, 'pendingPrintItems': pending});
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

  // --- IMPRIMIR TICKET (USB en Android, PDF en Web) ---
  Future<void> _generateAndPrintPdf(
    String tableName,
    List<MapEntry<String, dynamic>> items,
    double total,
  ) async {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'Camarero';

    await getPrintService().printTicket(
      context: context,
      tableName: tableName,
      items: items,
      total: total,
      userEmail: userEmail,
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
          'pendingPrintItems': {},
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

  // --- CONSTRUIR LISTA SEPARADA POR COMIDA Y BEBIDA ---
  Widget _buildSeparatedItemList(List<MapEntry<String, dynamic>> allItems) {
    final comidaItems = allItems.where((e) {
      final tipo = e.value['tipo'] as String? ?? 'comida';
      return tipo == 'comida';
    }).toList();

    final bebidaItems = allItems.where((e) {
      final tipo = e.value['tipo'] as String? ?? 'comida';
      return tipo == 'bebida';
    }).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        if (comidaItems.isNotEmpty) ...[
          _buildSectionHeader('🍽  Comida', Colors.orange.shade700),
          ...comidaItems.map((entry) => _buildItemTile(entry)),
        ],
        if (bebidaItems.isNotEmpty) ...[
          _buildSectionHeader('🥤  Bebida', Colors.blue.shade700),
          ...bebidaItems.map((entry) => _buildItemTile(entry)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border(
          left: BorderSide(color: color, width: 4),
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildItemTile(MapEntry<String, dynamic> itemEntry) {
    final itemName = itemEntry.key;
    final itemData = itemEntry.value;
    final itemPrice = (itemData['precio'] as num?)?.toDouble() ?? 0.0;
    final itemQuantity = (itemData['cantidad'] as num?)?.toInt() ?? 0;
    final subtotal = itemPrice * itemQuantity;
    final bool showPrices = widget.userRole == 'jefe';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila superior: nombre del producto + menú de opciones
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (showPrices)
                      Text(
                        '${itemPrice.toStringAsFixed(2)} € / ud.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
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
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Fila inferior: controles de cantidad + subtotal
          Row(
            children: [
              // Controles de cantidad
              IconButton(
                icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade700),
                onPressed: () => _updateItem(itemName, quantityChange: -1),
                tooltip: 'Quitar uno',
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                iconSize: 22,
              ),
              InkWell(
                onTap: () => _showQuantityDialog(itemName, itemQuantity),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                iconSize: 22,
              ),
              const Spacer(),
              if (showPrices)
                Text(
                  '${subtotal.toStringAsFixed(2)} €',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
            ],
          ),
          const Divider(height: 12),
        ],
      ),
    );
  }
  // --- IMPRIMIR ITEMS PENDIENTES DE COCINA ---
  Future<void> _printPendingItems(BuildContext context, Map<String, dynamic> tableData) async {
    final dynamic rawPending = tableData['pendingPrintItems'];
    if (rawPending == null || rawPending is! Map || rawPending.isEmpty) return;

    final Map<String, int> foodItems = {};
    for (final entry in rawPending.entries) {
      foodItems[entry.key as String] = (entry.value as num).toInt();
    }

    final tableName = tableData['nombre'] ?? widget.tableName;
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'Camarero';

    try {
      await getPrintService().printKitchenTicket(
        context: context,
        tableName: tableName,
        foodItems: foodItems,
        userEmail: userEmail,
      );

      // Si se imprimió correctamente, vaciar pendingPrintItems
      await FirebaseFirestore.instance
          .collection('mesas')
          .doc(widget.tableId)
          .update({'pendingPrintItems': {}});
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al imprimir: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
              // --- BOTÓN DE IMPRIMIR PENDIENTES (azul claro) ---
              if ((tableData['pendingPrintItems'] is Map) &&
                  (tableData['pendingPrintItems'] as Map).isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.print, color: Color(0xFF64B5F6)),
                  onPressed: () => _printPendingItems(context, tableData),
                  tooltip: 'Imprimir comanda cocina',
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
              : _buildSeparatedItemList(groupedItems),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SelectProductScreen(
                    tableId: widget.tableId,
                    tableName: currentTableName,
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