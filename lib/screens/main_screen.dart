import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'product_list_screen.dart';
import 'table_management_screen.dart';
import 'add_product_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    ProductListScreen(),
    TableManagementScreen(),
  ];

  static const List<String> _appBarTitles = <String>[
    'Gestión de Carta',
    'Gestión de Mesas',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

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
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitles[_selectedIndex]),
        actions: [
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
      // --- CORRECCIÓN IMPORTANTE AQUÍ ---
      // Hemos quitado el widget 'Center'. El body ahora es directamente
      // la pantalla seleccionada, permitiendo que ocupe todo el espacio.
      body: _widgetOptions.elementAt(_selectedIndex),
      
      // El FloatingActionButton se controla desde aquí para que solo aparezca
      // en la pantalla de la carta.
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const AddProductScreen()),
                );
              },
              tooltip: 'Añadir Producto',
              child: const Icon(Icons.add),
            )
          : null,
          
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'Carta',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.table_restaurant_outlined),
            label: 'Mesas',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

