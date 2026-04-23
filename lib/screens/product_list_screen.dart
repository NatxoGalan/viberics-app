import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_product_screen.dart';

class ProductListScreen extends StatefulWidget {
  final String userRole;

  const ProductListScreen({super.key, required this.userRole});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  String _searchQuery = '';
  late Stream<QuerySnapshot> _productosStream;

  @override
  void initState() {
    super.initState();
    // Un único stream ordenado por nombre — sin cláusula where para
    // evitar la necesidad de un índice compuesto en Firestore.
    _productosStream = FirebaseFirestore.instance
        .collection('productos')
        .orderBy('nombre')
        .snapshots();
  }

  Future<void> _deleteProduct(
      BuildContext context, String productId, String productName) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text(
              '¿Estás seguro de que quieres eliminar "$productName" de la carta?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Eliminar',
                  style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        await FirebaseFirestore.instance
            .collection('productos')
            .doc(productId)
            .delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"$productName" ha sido eliminado.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isJefe = widget.userRole == 'jefe';

    return Column(
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
            stream: _productosStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                    child: Text('No hay productos en la carta.'));
              }

              var products = snapshot.data!.docs;

              // Cocinero solo ve comida — filtrado en el cliente
              if (widget.userRole == 'cocinero') {
                products = products.where((p) {
                  final data = p.data() as Map<String, dynamic>;
                  return (data['tipo'] ?? '') == 'comida';
                }).toList();
              }

              // Filtro de búsqueda
              if (_searchQuery.isNotEmpty) {
                products = products.where((p) {
                  final nombre = ((p.data() as Map<String, dynamic>)['nombre']
                          as String? ??
                      '');
                  return nombre.toLowerCase().contains(_searchQuery);
                }).toList();
              }

              if (products.isEmpty) {
                return const Center(
                    child: Text('No se encontraron productos.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80.0),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  final data = product.data() as Map<String, dynamic>;
                  final nombre = data['nombre'] ?? 'Sin nombre';
                  final precio =
                      (data['precio'] as num?)?.toDouble() ?? 0.0;
                  final tipo = data['tipo'] ?? 'comida';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: tipo == 'comida'
                          ? Colors.orange.shade100
                          : Colors.blue.shade100,
                      child: Icon(
                        tipo == 'comida'
                            ? Icons.restaurant
                            : Icons.local_drink,
                        color: tipo == 'comida'
                            ? Colors.orange.shade700
                            : Colors.blue.shade700,
                      ),
                    ),
                    title: Text(nombre),
                    subtitle: Text('${precio.toStringAsFixed(2)} €'),
                    trailing: isJefe
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit,
                                    color: Theme.of(context).primaryColor),
                                tooltip: 'Editar',
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => AddProductScreen(
                                        product: product,
                                        userRole: widget.userRole,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete,
                                    color: Colors.red.shade700),
                                tooltip: 'Eliminar',
                                onPressed: () =>
                                    _deleteProduct(context, product.id, nombre),
                              ),
                            ],
                          )
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}