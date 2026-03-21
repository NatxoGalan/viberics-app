import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Este archivo no cambia, pero asegúrate de que está en la carpeta 'screens'
class AddProductScreen extends StatefulWidget {
  final DocumentSnapshot? product;

  const AddProductScreen({super.key, this.product});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _isEditing = true;
      final productData = widget.product!.data() as Map<String, dynamic>;
      _nameController.text = productData['nombre'];
      _priceController.text = productData['precio'].toString();
    }
  }

  void _saveProduct() async {
    final name = _nameController.text;
    final priceText = _priceController.text;

    if (name.isEmpty || priceText.isEmpty) return;

    final price = double.tryParse(priceText);
    if (price == null) return;

    if (_isEditing) {
      await FirebaseFirestore.instance
          .collection('productos')
          .doc(widget.product!.id)
          .update({
        'nombre': name,
        'precio': price,
      });
    } else {
      await FirebaseFirestore.instance.collection('productos').add({
        'nombre': name,
        'precio': price,
      });
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Producto' : 'Añadir Nuevo Producto'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nombre del Producto'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Precio'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveProduct,
              child: Text(_isEditing ? 'Actualizar' : 'Guardar Producto'),
            ),
          ],
        ),
      ),
    );
  }
}
