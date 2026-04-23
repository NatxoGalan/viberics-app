import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SelectProductScreen extends StatefulWidget {
  final String tableId;
  final String userRole;

  const SelectProductScreen(
      {super.key, required this.tableId, required this.userRole});

  @override
  State<SelectProductScreen> createState() => _SelectProductScreenState();
}

class _SelectProductScreenState extends State<SelectProductScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Un único stream con todos los productos — filtramos por tipo en el cliente
  // para evitar índices compuestos en Firestore (where + orderBy).
  late Stream<QuerySnapshot> _productosStream;

  bool get _isJefe => widget.userRole == 'jefe';
  bool get _isCamarero => widget.userRole == 'camarero';
  bool get _isCocinero => widget.userRole == 'cocinero';

  // Camarero → 1 tab (Bebida). Cocinero → 1 tab (Comida). Jefe → 2 tabs.
  int get _tabCount => _isJefe ? 2 : 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);

    _productosStream = FirebaseFirestore.instance
        .collection('productos')
        .orderBy('nombre')
        .snapshots();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addProductToTable(
      String productName, double productPrice) async {
    final firestore = FirebaseFirestore.instance;
    final tableRef = firestore.collection('mesas').doc(widget.tableId);
    final userEmail =
        FirebaseAuth.instance.currentUser?.email ?? 'Desconocido';

    await firestore.runTransaction((transaction) async {
      final tableSnapshot = await transaction.get(tableRef);
      if (!tableSnapshot.exists) {
        throw Exception('La mesa no existe!');
      }

      final tableData = tableSnapshot.data() as Map<String, dynamic>;
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
        items[productName]['cantidad'] =
            (items[productName]['cantidad'] ?? 0) + 1;
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

      final logEntry = {
        'accion': actionLog,
        'producto': productName,
        'camarero': userEmail,
        'fecha': FieldValue.serverTimestamp(),
      };
      transaction.set(tableRef.collection('log').doc(), logEntry);

      transaction.update(tableRef, {
        'items': items,
        'total': newTotal,
        'estado': 'Ocupada',
      });
    });
  }

  /// Construye la lista de productos filtrada por [tipo] ('comida' o 'bebida').
  Widget _buildProductList(
      List<QueryDocumentSnapshot> allProducts, String tipo) {
    final bool showPrices = !_isCamarero;

    final filtered = allProducts.where((p) {
      final data = p.data() as Map<String, dynamic>;
      final tipoP = data['tipo'] ?? 'comida';
      if (tipoP != tipo) return false;
      if (_searchQuery.isEmpty) return true;
      final nombre = (data['nombre'] as String? ?? '').toLowerCase();
      return nombre.contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tipo == 'comida' ? Icons.no_food : Icons.no_drinks,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'No hay ${tipo == 'comida' ? 'comidas' : 'bebidas'} disponibles.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final product = filtered[index];
        final data = product.data() as Map<String, dynamic>;
        final nombre = data['nombre'] ?? 'Sin nombre';
        final precio = (data['precio'] as num?)?.toDouble() ?? 0.0;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: tipo == 'comida'
                ? Colors.orange.shade100
                : Colors.blue.shade100,
            child: Icon(
              tipo == 'comida' ? Icons.restaurant : Icons.local_drink,
              color: tipo == 'comida'
                  ? Colors.orange.shade700
                  : Colors.blue.shade700,
            ),
          ),
          title: Text(nombre),
          subtitle: showPrices
              ? Text('${precio.toStringAsFixed(2)} €')
              : null,
          onTap: () {
            _addProductToTable(nombre, precio);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tabs según el rol
    final List<Tab> tabs;
    if (_isJefe) {
      tabs = const [
        Tab(icon: Icon(Icons.restaurant), text: 'Comida'),
        Tab(icon: Icon(Icons.local_drink), text: 'Bebida'),
      ];
    } else if (_isCocinero) {
      tabs = const [Tab(icon: Icon(Icons.restaurant), text: 'Comida')];
    } else {
      tabs = const [Tab(icon: Icon(Icons.local_drink), text: 'Bebida')];
    }

    // Tipo(s) que verá cada tab
    final List<String> tipos;
    if (_isJefe) {
      tipos = ['comida', 'bebida'];
    } else if (_isCocinero) {
      tipos = ['comida'];
    } else {
      tipos = ['bebida'];
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir a la mesa'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).primaryColor,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          tabs: tabs,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
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
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('No hay productos disponibles.'));
                }

                final allProducts = snapshot.data!.docs;

                return TabBarView(
                  controller: _tabController,
                  children: tipos
                      .map((tipo) => _buildProductList(allProducts, tipo))
                      .toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}