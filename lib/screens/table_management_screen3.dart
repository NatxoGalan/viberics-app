import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_table_screen.dart';
import 'log_screen.dart'; // Importamos la nueva pantalla de log
import 'table_detail_screen.dart';

class TableManagementScreen extends StatelessWidget {
  const TableManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('mesas').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar las mesas'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay mesas. ¡Crea la primera!'));
          }

          final tables = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(10.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10.0,
              mainAxisSpacing: 10.0,
              childAspectRatio: 3 / 2,
            ),
            itemCount: tables.length,
            itemBuilder: (context, index) {
              final table = tables[index];
              final tableData = table.data() as Map<String, dynamic>;
              final tableName = tableData['nombre'] ?? 'Sin Nombre';
              final tableGuests = tableData['comensales'] ?? 0;
              final tableStatus = tableData['estado'] ?? 'Desconocido';

              return InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => TableDetailScreen(
                        tableId: table.id,
                        tableName: tableName,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Card(
                  elevation: 4.0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch, // Para alinear el botón
                      children: [
                        Text(
                          tableName,
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_alt_outlined, color: Colors.grey[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '$tableGuests comensales',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tableStatus,
                          style: TextStyle(
                            color: tableStatus == 'Libre' ? Colors.green.shade700 : Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const Spacer(), // Ocupa el espacio restante
                        // --- BOTÓN PARA VER EL HISTORIAL ---
                        Align(
                          alignment: Alignment.bottomRight,
                          child: IconButton(
                            icon: const Icon(Icons.history),
                            tooltip: 'Ver historial de la mesa',
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => LogScreen(
                                    tableId: table.id,
                                    tableName: tableName,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddTableScreen()),
          );
        },
        tooltip: 'Añadir Mesa',
        child: const Icon(Icons.add),
      ),
    );
  }
}
