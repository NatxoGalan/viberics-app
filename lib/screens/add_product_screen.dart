import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddProductScreen extends StatefulWidget {
  final DocumentSnapshot? product;
  final String userRole;

  const AddProductScreen({
    super.key,
    this.product,
    this.userRole = 'jefe',
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isEditing = false;
  late String _selectedType;

  /// El tipo está fijo si el rol es camarero o cocinero.
  bool get _tipoFijo =>
      widget.userRole == 'camarero' || widget.userRole == 'cocinero';

  @override
  void initState() {
    super.initState();

    // Tipo por defecto según el rol
    if (widget.userRole == 'camarero') {
      _selectedType = 'bebida';
    } else if (widget.userRole == 'cocinero') {
      _selectedType = 'comida';
    } else {
      _selectedType = 'comida'; // jefe: empieza en comida pero puede cambiar
    }

    if (widget.product != null) {
      _isEditing = true;
      final productData = widget.product!.data() as Map<String, dynamic>;
      _nameController.text = productData['nombre'];
      _priceController.text = productData['precio'].toString();
      // Al editar, respetamos el tipo guardado (pero limitamos si el rol lo restringe)
      final savedType = productData['tipo'] ?? 'comida';
      if (!_tipoFijo) {
        _selectedType = savedType;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _saveProduct() async {
    final name = _nameController.text.trim();
    final priceText = _priceController.text.trim();

    if (name.isEmpty || priceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, rellena todos los campos.')),
      );
      return;
    }

    final price = double.tryParse(priceText.replaceAll(',', '.'));
    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El precio no es válido.')),
      );
      return;
    }

    if (_isEditing) {
      await FirebaseFirestore.instance
          .collection('productos')
          .doc(widget.product!.id)
          .update({
        'nombre': name,
        'precio': price,
        'tipo': _selectedType,
      });
    } else {
      await FirebaseFirestore.instance.collection('productos').add({
        'nombre': name,
        'precio': price,
        'tipo': _selectedType,
      });
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String tipoLabel =
        _selectedType == 'bebida' ? '🥤 Bebida' : '🍽️ Comida';

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Producto' : 'Añadir Nuevo Producto'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration:
                  const InputDecoration(labelText: 'Nombre del Producto'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Precio (€)',
                hintText: 'Ej: 2.50',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),

            // Si el tipo está fijo por rol, mostramos un chip informativo.
            // Si es jefe, mostramos el dropdown completo.
            if (_tipoFijo)
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tipo de Producto',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  children: [
                    Text(tipoLabel,
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Fijo por tu rol',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Producto',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'comida', child: Text('🍽️ Comida')),
                  DropdownMenuItem(
                      value: 'bebida', child: Text('🥤 Bebida')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedType = value;
                    });
                  }
                },
              ),

            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _saveProduct,
              icon: Icon(_isEditing ? Icons.save : Icons.add),
              label: Text(_isEditing ? 'Actualizar' : 'Guardar Producto'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
