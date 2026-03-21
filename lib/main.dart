import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth_wrapper.dart';

void main() {
  // Nos aseguramos de que Flutter esté listo
  WidgetsFlutterBinding.ensureInitialized();
  // Lanzamos la aplicación
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestor de Comandas',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // Usamos un FutureBuilder para manejar la inicialización de Firebase
      home: FutureBuilder(
        // El 'future' que intentamos resolver es la inicialización de Firebase
        future: Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ),
        builder: (context, snapshot) {
          // Si el snapshot tiene un error, lo mostramos en pantalla
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text(
                  'Error al inicializar Firebase: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // Si la conexión se completa con éxito, mostramos el AuthWrapper
          if (snapshot.connectionState == ConnectionState.done) {
            return const AuthWrapper();
          }

          // Mientras se está inicializando, mostramos un círculo de carga
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
      ),
    );
  }
}

