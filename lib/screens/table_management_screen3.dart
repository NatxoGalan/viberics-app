import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_table_screen.dart';
import 'log_screen.dart'; 
import 'table_detail_screen.dart';

class TableManagementScreen extends StatefulWidget {
  const TableManagementScreen({super.key});

  @override
  State<TableManagementScreen> createState() => _TableManagementScreenState();
}

class _TableManagementScreenState extends State<TableManagementScreen> {
  // 1. Creamos una variable para guardar el Stream
  late Stream<QuerySnapshot> _mesasStream;

  @override
  void initState() {
    super.initState();
    // 2. Iniciamos la conexión a Firebase UNA SOLA VEZ cuando se abre la pantalla
    _mesasStream = FirebaseFirestore.instance.collection('mesas').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        // 3. Usamos la variable guardada en lugar de llamar a Firebase aquí
        stream: _mesasStream,
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
                        userRole: 'jefe',
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        const Spacer(),
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