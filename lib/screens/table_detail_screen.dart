import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'select_product_screen.dart';

class TableDetailScreen extends StatefulWidget {
  final String tableId;
  final String tableName;

  const TableDetailScreen({
    super.key,
    required this.tableId,
    required this.tableName,
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
              // --- BOTÓN DE EDITAR NOMBRE AÑADIDO AQUÍ ---
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editTableName(context, currentTableName),
                tooltip: 'Cambiar Nombre',
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
                  builder: (context) => SelectProductScreen(tableId: widget.tableId),
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