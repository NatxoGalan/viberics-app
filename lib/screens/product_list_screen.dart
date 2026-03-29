import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_product_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  String _searchQuery = '';
  // 1. Añadimos la variable para el Stream
  late Stream<QuerySnapshot> _productosStream;

  @override
  void initState() {
    super.initState();
    // 2. Iniciamos el Stream una sola vez
    _productosStream = FirebaseFirestore.instance
        .collection('productos')
        .orderBy('nombre')
        .snapshots();
  }

  Future<void> _deleteProduct(BuildContext context, String productId, String productName) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text('¿Estás seguro de que quieres eliminar "$productName" de la carta?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        await FirebaseFirestore.instance.collection('productos').doc(productId).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"$productName" ha sido eliminado.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar el producto: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            // 3. Usamos el stream guardado
            stream: _productosStream,
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
                padding: const EdgeInsets.only(bottom: 80.0),
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  final productData = product.data() as Map<String, dynamic>;
                  final productName = productData['nombre'] ?? 'Sin Nombre';
                  final productPrice = (productData['precio'] as num?)?.toDouble() ?? 0.0;

                  return ListTile(
                    title: Text(productName),
                    subtitle: Text('${productPrice.toStringAsFixed(2)} €'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, color: Theme.of(context).primaryColor),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => AddProductScreen(product: product),
                              ),
                            );
                          },
                          tooltip: 'Editar',
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red.shade700),
                          onPressed: () {
                            _deleteProduct(context, product.id, productName);
                          },
                          tooltip: 'Eliminar',
                        ),
                      ],
                    ),
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