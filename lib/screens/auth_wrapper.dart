import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:viberics_app/screens/login_screen.dart';
import 'package:viberics_app/screens/main_screen.dart';


class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // StreamBuilder escucha los cambios en el estado de autenticación de Firebase
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Mientras espera la conexión, muestra un indicador de carga
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Si hay un usuario en el snapshot, significa que ha iniciado sesión
        if (snapshot.hasData) {
          // Por lo tanto, muestra la pantalla principal de la aplicación
          return const MainScreen();
        } else {
          // Si no hay datos de usuario, muestra la pantalla de login
          return const LoginScreen();
        }
      },
    );
  }
}

