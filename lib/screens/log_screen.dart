import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Necesitarás añadir este paquete

class LogScreen extends StatelessWidget {
  final String tableId;
  final String tableName;

  const LogScreen({
    super.key,
    required this.tableId,
    required this.tableName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historial: $tableName'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Apuntamos a la subcolección 'log' de la mesa específica
        stream: FirebaseFirestore.instance
            .collection('mesas')
            .doc(tableId)
            .collection('log')
            .orderBy('fecha', descending: true) // Ordenamos por fecha
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar el historial'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay actividad registrada.'));
          }

          final logEntries = snapshot.data!.docs;

          return ListView.builder(
            itemCount: logEntries.length,
            itemBuilder: (context, index) {
              final entry = logEntries[index];
              final data = entry.data() as Map<String, dynamic>;

              final String accion = data['accion'] ?? 'Acción desconocida';
              final String producto = data['producto'] ?? '';
              final String camarero = data['camarero'] ?? 'Desconocido';
              final Timestamp timestamp = data['fecha'] ?? Timestamp.now();
              
              // Formatear la fecha para que sea legible
              final DateTime fecha = timestamp.toDate();
              final String fechaFormateada = DateFormat('dd/MM/yy HH:mm').format(fecha);

              return ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text('$accion: $producto'),
                subtitle: Text('Por $camarero - $fechaFormateada'),
              );
            },
          );
        },
      ),
    );
  }
}

