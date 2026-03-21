import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';


class AddTableScreen extends StatefulWidget {
  const AddTableScreen({super.key});

  @override
  State<AddTableScreen> createState() => _AddTableScreenState();
}

class _AddTableScreenState extends State<AddTableScreen> {
  final _nameController = TextEditingController();
  final _guestsController = TextEditingController();

  void _saveTable() async {
    final name = _nameController.text;
    final guestsText = _guestsController.text;

    if (name.isEmpty || guestsText.isEmpty) {
      // Mostrar error si los campos están vacíos
      return;
    }

    final guests = int.tryParse(guestsText);
    if (guests == null) {
      // Mostrar error si los comensales no son un número válido
      return;
    }

    // Guardar la nueva mesa en la colección 'mesas'
    await FirebaseFirestore.instance.collection('mesas').add({
      'nombre': name,
      'comensales': guests,
      'estado': 'Libre',
      
      // --- CORRECCIÓN AÑADIDA AQUÍ ---
      // Se añaden los valores relativos por defecto para que la mesa sea visible.
      'dx': 0.05, // Posición X: 5% desde la izquierda
      'dy': 0.05, // Posición Y: 5% desde arriba
      'width': 0.4, // Ancho: 40% del ancho de la pantalla
      'height': 0.45, // Alto: 45% del ancho de la pantalla
    });

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Nueva Mesa'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nombre o ubicación de la mesa'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _guestsController,
              decoration: const InputDecoration(labelText: 'Nº de comensales/sillas'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveTable,
              child: const Text('Guardar Mesa'),
            ),
          ],
        ),
      ),
    );
  }
}