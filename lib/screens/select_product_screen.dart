import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <-- 1. IMPORT NECESARIO

class SelectProductScreen extends StatefulWidget {
  final String tableId;
  const SelectProductScreen({super.key, required this.tableId});

  @override
  State<SelectProductScreen> createState() => _SelectProductScreenState();
}

class _SelectProductScreenState extends State<SelectProductScreen> {
  String _searchQuery = '';

  Future<void> _addProductToTable(String productName, double productPrice) async {
    final firestore = FirebaseFirestore.instance;
    final tableRef = firestore.collection('mesas').doc(widget.tableId);
    // --- 2. OBTENER EL USUARIO ACTUAL PARA EL LOG ---
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'Desconocido';

    await firestore.runTransaction((transaction) async {
      final tableSnapshot = await transaction.get(tableRef);
      if (!tableSnapshot.exists) {
        throw Exception("La mesa no existe!");
      }

      final tableData = tableSnapshot.data() as Map<String, dynamic>;
      final dynamic rawItems = tableData['items'];
      final Map<String, dynamic> items = {};

      // Tu lógica para manejar y convertir la lista de items
      if (rawItems is Map) {
        items.addAll(Map<String, dynamic>.from(rawItems));
      } else if (rawItems is List) {
        for (var item in rawItems) {
          if (item is Map) {
            final String? name = item['nombre'];
            final num? price = item['precio'];
            if (name != null && price != null) {
              if (items.containsKey(name)) {
                items[name]['cantidad'] = (items[name]['cantidad'] ?? 0) + 1;
              } else {
                items[name] = {'precio': price, 'cantidad': 1};
              }
            }
          }
        }
      }
      
      String actionLog;
      if (items.containsKey(productName)) {
        items[productName]['cantidad'] = (items[productName]['cantidad'] ?? 0) + 1;
        actionLog = 'Añadió 1 unidad';
      } else {
        items[productName] = {'precio': productPrice, 'cantidad': 1};
        actionLog = 'Añadió a la comanda';
      }

      double newTotal = 0.0;
      items.forEach((key, value) {
        final itemPrice = (value['precio'] as num?)?.toDouble() ?? 0.0;
        final itemQuantity = (value['cantidad'] as num?)?.toInt() ?? 0;
        newTotal += itemPrice * itemQuantity;
      });

      // --- 3. LÓGICA DE LOG AÑADIDA AQUÍ ---
      // Se crea la entrada del log antes de guardar los cambios
      final logEntry = {
        'accion': actionLog,
        'producto': productName,
        'camarero': userEmail,
        'fecha': FieldValue.serverTimestamp(),
      };
      // Se añade la operación de crear el log a la transacción
      transaction.set(tableRef.collection('log').doc(), logEntry);

      // Finalmente, se actualiza la mesa
      transaction.update(tableRef, {
        'items': items,
        'total': newTotal,
        'estado': 'Ocupada',
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Producto'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Buscar producto',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('productos').orderBy('nombre').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error al cargar los productos'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No hay productos en la carta.'));
                }

                final products = snapshot.data!.docs;

                final filteredProducts = _searchQuery.isEmpty
                    ? products
                    : products.where((product) {
                        final productName = (product.data() as Map<String, dynamic>)['nombre']
                            .toString()
                            .toLowerCase();
                        return productName.contains(_searchQuery);
                      }).toList();
                
                if (filteredProducts.isEmpty) {
                  return const Center(child: Text('No se encontraron productos.'));
                }

                return ListView.builder(
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    final productData = product.data() as Map<String, dynamic>;
                    final productName = productData['nombre'] ?? 'Sin Nombre';
                    final productPrice = (productData['precio'] as num?)?.toDouble() ?? 0.0;

                    return ListTile(
                      title: Text(productName),
                      subtitle: Text('${productPrice.toStringAsFixed(2)} €'),
                      onTap: () {
                        _addProductToTable(productName, productPrice);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}