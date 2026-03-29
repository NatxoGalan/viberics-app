import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'table_detail_screen.dart';
import 'add_table_screen.dart';
import 'log_screen.dart';

// Límites en píxeles para el tamaño de las tarjetas
const double minCardWidth = 100.0;
const double maxCardWidth = 260.0;
const double minCardHeight = 134.0;
const double maxCardHeight = 260.0;

// Rejilla extrafina para un control preciso
const double snapGridSize = 2.0;

class TableManagementScreen extends StatefulWidget {
  const TableManagementScreen({super.key});

  @override
  State<TableManagementScreen> createState() => _TableManagementScreenState();
}

class _TableManagementScreenState extends State<TableManagementScreen> {
  final GlobalKey _stackKey = GlobalKey();
  
  // --- 1. VARIABLE PARA GUARDAR LA CONEXIÓN ---
  late Stream<QuerySnapshot> _mesasStream;

  @override
  void initState() {
    super.initState();
    // --- 2. PEDIMOS LOS DATOS A FIREBASE UNA SOLA VEZ ---
    _mesasStream = FirebaseFirestore.instance.collection('mesas').snapshots();
  }

  void _updateTableSize(String tableId, double width, double height, Size screenSize) {
    FirebaseFirestore.instance.collection('mesas').doc(tableId).update({
      'width': width / screenSize.width,
      'height': height / screenSize.width,
    });
  }

  void _showEditDialog(BuildContext context, DocumentSnapshot table, Size screenSize) {
    final tableData = table.data() as Map<String, dynamic>;

    double relativeWidth = (tableData['width'] as num?)?.toDouble() ?? 0.3;
    double relativeHeight = (tableData['height'] as num?)?.toDouble() ?? 0.35;
    
    double widthInPixels = (relativeWidth * screenSize.width).clamp(minCardWidth, maxCardWidth);
    double heightInPixels = (relativeHeight * screenSize.width).clamp(minCardHeight, maxCardHeight);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Editar "${tableData['nombre']}"'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Ancho: ${widthInPixels.toStringAsFixed(0)}px'),
                    Slider(
                      value: widthInPixels,
                      min: minCardWidth,
                      max: maxCardWidth,
                      onChanged: (value) => setState(() => widthInPixels = value),
                    ),
                    Text('Alto: ${heightInPixels.toStringAsFixed(0)}px'),
                    Slider(
                      value: heightInPixels,
                      min: minCardHeight,
                      max: maxCardHeight,
                      onChanged: (value) => setState(() => heightInPixels = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _updateTableSize(table.id, widthInPixels, heightInPixels, screenSize);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTableLog(BuildContext context, DocumentSnapshot table) {
     Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LogScreen(
          tableId: table.id,
          tableName: (table.data() as Map<String, dynamic>)['nombre'] ?? 'Mesa',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final availableSize = constraints.biggest;

          return StreamBuilder<QuerySnapshot>(
            // --- 3. USAMOS LA VARIABLE AQUÍ PARA NO GASTAR LECTURAS ---
            stream: _mesasStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error al cargar las mesas: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text('No hay mesas creadas. Añade una para empezar.'),
                );
              }

              final tables = snapshot.data!.docs;

              return Stack(
                key: _stackKey,
                children: tables.map((table) {
                  final tableData = table.data() as Map<String, dynamic>;

                  final double relativeDx = (tableData['dx'] as num?)?.toDouble() ?? 0.05;
                  final double relativeDy = (tableData['dy'] as num?)?.toDouble() ?? 0.05;
                  
                  final double absoluteDx = relativeDx * availableSize.width;
                  final double absoluteDy = relativeDy * availableSize.height;

                  Widget tableWidget = _TableWidget(
                    table: table,
                    screenSize: availableSize,
                    onLogTap: () => _showTableLog(context, table),
                    onLongPress: () => _showEditDialog(context, table, availableSize),
                  );

                  return Positioned(
                    left: absoluteDx,
                    top: absoluteDy,
                    child: Draggable(
                      feedback: tableWidget,
                      childWhenDragging: Container(),
                      onDragEnd: (details) {
                        final RenderBox stackRenderBox = _stackKey.currentContext!.findRenderObject() as RenderBox;
                        final localOffset = stackRenderBox.globalToLocal(details.offset);

                        final tableData = table.data() as Map<String, dynamic>;
                        final double relativeWidth = (tableData['width'] as num?)?.toDouble() ?? 0.3;
                        final double relativeHeight = (tableData['height'] as num?)?.toDouble() ?? 0.35;
                        final double cardWidth = (relativeWidth * availableSize.width).clamp(minCardWidth, maxCardWidth);
                        final double cardHeight = (relativeHeight * availableSize.width).clamp(minCardHeight, maxCardHeight);

                        final double maxDx = availableSize.width - cardWidth;
                        final double maxDy = availableSize.height - cardHeight;
                        
                        final double snappedDx = (localOffset.dx / snapGridSize).round() * snapGridSize;
                        final double snappedDy = (localOffset.dy / snapGridSize).round() * snapGridSize;

                        final double clampedDx = snappedDx.clamp(0.0, maxDx);
                        final double clampedDy = snappedDy.clamp(0.0, maxDy);

                        FirebaseFirestore.instance.collection('mesas').doc(table.id).update({
                          'dx': clampedDx / availableSize.width,
                          'dy': clampedDy / availableSize.height,
                        });
                      },
                      child: tableWidget,
                    ),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const AddTableScreen()),
        ),
        tooltip: 'Añadir Mesa',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TableWidget extends StatelessWidget {
  final DocumentSnapshot table;
  final Size screenSize;
  final VoidCallback onLogTap;
  final VoidCallback onLongPress;

  const _TableWidget({
    required this.table,
    required this.screenSize,
    required this.onLogTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final tableData = table.data() as Map<String, dynamic>;
    
    final double relativeWidth = (tableData['width'] as num?)?.toDouble() ?? 0.3;
    final double relativeHeight = (tableData['height'] as num?)?.toDouble() ?? 0.35;
    
    final double widthInPixels = (relativeWidth * screenSize.width).clamp(minCardWidth, maxCardWidth);
    final double heightInPixels = (relativeHeight * screenSize.width).clamp(minCardHeight, maxCardHeight);

    final String tableName = tableData['nombre'] ?? 'Sin Nombre';
    final String tableStatus = tableData['estado'] ?? 'Libre';
    final int guestCount = tableData['comensales'] ?? 0;

    final Color borderColor;
    switch (tableStatus) {
      case 'Ocupada':
        borderColor = Colors.orange.shade700;
        break;
      default:
        borderColor = Colors.green.shade700;
    }

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => TableDetailScreen(tableId: table.id, tableName: tableName,)), // Corrección menor: pasamos el nombre real
      ),
      onLongPress: onLongPress,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: widthInPixels,
          height: heightInPixels,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 2.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(9),
                    topRight: Radius.circular(9),
                  ),
                ),
                child: Text(
                  tableName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 2),
                      Text(
                        '$guestCount ',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade800),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.receipt_long_outlined),
                color: Colors.blueGrey.shade700,
                tooltip: 'Ver Historial',
                onPressed: onLogTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}