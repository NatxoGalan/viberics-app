import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Obtiene el rol del usuario actual desde la colección 'usuarios' de Firestore.
/// Devuelve 'jefe' por defecto si el documento no existe o no tiene el campo 'rol'.
Future<String> getUserRole() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return 'jefe';

  try {
    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .get();

    if (doc.exists && doc.data() != null) {
      return (doc.data()!['rol'] as String?) ?? 'jefe';
    }
  } catch (e) {
    // Si hay error al leer, asumimos jefe para no bloquear la app
  }

  return 'jefe';
}
