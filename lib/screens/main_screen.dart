import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'product_list_screen.dart';
import 'table_management_screen.dart';
import 'add_product_screen.dart';

class MainScreen extends StatefulWidget {
  final String userRole;

  const MainScreen({super.key, required this.userRole});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _forgetAndLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('email');
    await prefs.remove('password');
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final bool isJefe = widget.userRole == 'jefe';

    // Si es jefe: Carta (index 0) + Mesas (index 1)
    // Si no es jefe: solo Mesas (index 0)
    final bool isCocinero = widget.userRole == 'cocinero';
    final bool isCamarero = widget.userRole == 'camarero';

    // Jefe y Cocinero: Carta + Mesas. Camarero: solo Mesas.
    final List<Widget> widgetOptions;
    if (!isCamarero) {
      widgetOptions = [
        ProductListScreen(userRole: widget.userRole),
        TableManagementScreen(userRole: widget.userRole),
      ];
    } else {
      widgetOptions = [
        TableManagementScreen(userRole: widget.userRole),
      ];
    }

    final List<String> appBarTitles = !isCamarero
        ? ['Gestión de Carta', 'Gestión de Mesas']
        : ['Gestión de Mesas'];

    final List<BottomNavigationBarItem> navItems = !isCamarero
        ? const [
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book),
              label: 'Carta',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.table_restaurant_outlined),
              label: 'Mesas',
            ),
          ]
        : const [
            BottomNavigationBarItem(
              icon: Icon(Icons.table_restaurant_outlined),
              label: 'Mesas',
            ),
          ];

    // Determinar el texto del rol para mostrarlo
    String rolLabel;
    switch (widget.userRole) {
      case 'camarero':
        rolLabel = '🍹 Camarero';
        break;
      case 'cocinero':
        rolLabel = '🍳 Cocinero';
        break;
      default:
        rolLabel = '👑 Jefe';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitles[_selectedIndex]),
        actions: [
          // Mostrar el rol del usuario
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                rolLabel,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.person_outline),
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              } else if (value == 'forget_logout') {
                _forgetAndLogout();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'logout',
                child: Text('Cerrar Sesión'),
              ),
              const PopupMenuItem<String>(
                value: 'forget_logout',
                child: Text('Olvidar y Salir'),
              ),
            ],
          ),
        ],
      ),
      body: widgetOptions.elementAt(_selectedIndex),
      
      // FAB solo para jefe y cocinero en la pestaña Carta
      floatingActionButton: (!isCamarero && _selectedIndex == 0)
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        AddProductScreen(userRole: widget.userRole),
                  ),
                );
              },
              tooltip: 'Añadir Producto',
              child: const Icon(Icons.add),
            )
          : null,
          
      // BottomNavigationBar solo si hay más de una pestaña
      bottomNavigationBar: navItems.length > 1
          ? BottomNavigationBar(
              items: navItems,
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            )
          : null,
    );
  }
}
