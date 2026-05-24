import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/print_service.dart';

class SelectProductScreen extends StatefulWidget {
  final String tableId;
  final String tableName;
  final String userRole;

  const SelectProductScreen({
    super.key,
    required this.tableId,
    required this.tableName,
    required this.userRole,
  });

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

  // --- ACUMULADOR DE COMIDA AÑADIDA EN ESTA SESIÓN ---
  // Clave: nombre del producto, Valor: cantidad añadida en esta sesión
  final Map<String, int> _addedFoodItems = {};
  int get _totalAddedItems => _addedFoodItems.values.fold(0, (a, b) => a + b);

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
      String productName, double productPrice, String productType) async {
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
        items[productName] = {'precio': productPrice, 'cantidad': 1, 'tipo': productType};
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

    // Acumular comida añadida para el ticket de cocina
    if (productType == 'comida') {
      setState(() {
        _addedFoodItems[productName] = (_addedFoodItems[productName] ?? 0) + 1;
      });
    }
  }

  /// Imprime el ticket de cocina con los items de comida acumulados.
  Future<void> _printKitchenTicket() async {
    if (_addedFoodItems.isEmpty) return;

    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'Camarero';

    try {
      await getPrintService().printKitchenTicket(
        context: context,
        tableName: widget.tableName,
        foodItems: _addedFoodItems,
        userEmail: userEmail,
      );
    } catch (e) {
      // Si falla la impresión, no bloquear la navegación
      debugPrint('Error al imprimir ticket de cocina: $e');
    }
  }

  bool _canPop = false;
  bool _isPopping = false;

  /// Al salir de la pantalla, imprimir ticket de cocina si hay comida añadida.
  Future<void> _handlePop() async {
    if (_isPopping) return;
    setState(() {
      _isPopping = true;
    });

    if (_addedFoodItems.isNotEmpty) {
      await _printKitchenTicket();
    }
    
    if (context.mounted) {
      setState(() {
        _canPop = true;
      });
      // Esperar al siguiente frame para que PopScope se actualice con canPop = true
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      });
    }
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

        // Mostrar cuántos se han añadido en esta sesión
        final int addedCount = (tipo == 'comida')
            ? (_addedFoodItems[nombre] ?? 0)
            : 0;

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
          trailing: addedCount > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+$addedCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                )
              : null,
          onTap: () {
            _addProductToTable(nombre, precio, tipo);
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✓ $nombre añadido'),
                duration: const Duration(seconds: 1),
                backgroundColor: tipo == 'comida'
                    ? Colors.orange.shade700
                    : Colors.blue.shade700,
              ),
            );
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

    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handlePop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Añadir a ${widget.tableName}'),
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
            // Banner de items añadidos
            if (_totalAddedItems > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.orange.shade50,
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$_totalAddedItems comida(s) añadida(s) — se imprimirá ticket al salir',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
        // Botón "Listo" para volver
        floatingActionButton: _totalAddedItems > 0
            ? FloatingActionButton.extended(
                onPressed: () {
                  _handlePop();
                },
                icon: const Icon(Icons.check),
                label: Text('Listo ($_totalAddedItems)'),
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              )
            : null,
      ),
    );
  }
}