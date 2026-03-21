import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'select_product_screen.dart';

class TableDetailScreen extends StatelessWidget {
  final String tableId;
  final String tableName;

  const TableDetailScreen({
    super.key,
    required this.tableId,
    required this.tableName,
  });

  Future<void> _updateItem(String itemName, {int? quantityChange, bool deleteItem = false}) async {
    // ... (Tu código original sin cambios)
    final firestore = FirebaseFirestore.instance;
    final tableRef = firestore.collection('mesas').doc(tableId);
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
          return; // No action needed
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

  Future<void> _updateItemPrice(BuildContext context, String itemName) async {
    // ... (Tu código original sin cambios)
     final firestore = FirebaseFirestore.instance;
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'Desconocido';

    try {
      final productQuery = await firestore
          .collection('productos')
          .where('nombre', isEqualTo: itemName)
          .limit(1)
          .get();

      if (productQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$itemName" ya no se encuentra en la carta.')),
        );
        return;
      }

      final newPrice = (productQuery.docs.first.data()['precio'] as num).toDouble();

      await firestore.runTransaction((transaction) async {
        final tableRef = firestore.collection('mesas').doc(tableId);
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Precio de "$itemName" actualizado.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar: $e')),
      );
    }
  }
  
  // --- FUNCIÓN NUEVA AÑADIDA AQUÍ ---
  // Vacía la comanda y el historial, pero no borra la mesa del plano.
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
        final tableRef = firestore.collection('mesas').doc(tableId);
        final logCollectionRef = tableRef.collection('log');

        // Usamos un batch para realizar ambas operaciones a la vez
        final batch = firestore.batch();

        // 1. Borrar todos los documentos del log
        final logSnapshot = await logCollectionRef.get();
        for (final doc in logSnapshot.docs) {
          batch.delete(doc.reference);
        }

        // 2. Actualizar la mesa para vaciarla
        batch.update(tableRef, {
          'items': {},
          'total': 0.0,
          'estado': 'Libre',
        });

        // Ejecutar todas las operaciones
        await batch.commit();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Mesa "$tableName" vaciada correctamente.')),
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
    // ... (Tu código original sin cambios)
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
        final tableRef = firestore.collection('mesas').doc(tableId);
        final logCollectionRef = tableRef.collection('log');

        // Borrar todos los documentos del log en un batch
        final logSnapshot = await logCollectionRef.get();
        final batch = firestore.batch();
        for (final doc in logSnapshot.docs) {
          batch.delete(doc.reference);
        }

        // Borrar la mesa principal
        batch.delete(tableRef);

        // Ejecutar todas las operaciones de borrado
        await batch.commit();

        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Mesa "$tableName" eliminada.')),
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
    final DocumentReference tableRef =
        FirebaseFirestore.instance.collection('mesas').doc(tableId);

    return StreamBuilder<DocumentSnapshot>(
      stream: tableRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
              appBar: AppBar(title: Text('Comanda: $tableName')),
              body: const Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
              appBar: AppBar(title: Text('Comanda: $tableName')),
              body: const Center(child: Text('Esta mesa ya no existe.')));
        }

        final tableData = snapshot.data!.data() as Map<String, dynamic>;
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
            title: Text('Comanda: $tableName'),
            // --- CAMBIO AQUÍ: Añadido el botón de vaciar mesa ---
            actions: [
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

                    return ListTile(
                      title: Text(itemName),
                      subtitle: Text('${itemPrice.toStringAsFixed(2)} € / ud.'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade700),
                            onPressed: () => _updateItem(itemName, quantityChange: -1),
                            tooltip: 'Quitar uno',
                          ),
                          Text(
                            '$itemQuantity',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
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
                  builder: (context) => SelectProductScreen(tableId: tableId),
                ),
              );
            },
            tooltip: 'Añadir Producto',
            child: const Icon(Icons.add_shopping_cart),
          ),
          bottomNavigationBar: BottomAppBar(
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
          ),
        );
      },
    );
  }
}