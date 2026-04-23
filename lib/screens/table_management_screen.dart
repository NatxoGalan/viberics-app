import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'table_detail_screen.dart';
import 'add_table_screen.dart';
import 'log_screen.dart';

// Rejilla extrafina para un control preciso
const double snapGridSize = 2.0;

// Límites de tarjeta según tipo de dispositivo
class CardLimits {
  final double minW, maxW, minH, maxH;
  const CardLimits(this.minW, this.maxW, this.minH, this.maxH);

  factory CardLimits.forScreen(double screenWidth) {
    if (screenWidth > 600) {
      // Tablet
      return const CardLimits(160, 320, 180, 340);
    } else {
      // Móvil: mínimo 100x111
      return const CardLimits(100, 260, 111, 260);
    }
  }
}

class TableManagementScreen extends StatefulWidget {
  final String userRole;
  const TableManagementScreen({super.key, required this.userRole});

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

  void _updateTableSize(
    String tableId,
    double width,
    double height,
    Size screenSize,
  ) {
    FirebaseFirestore.instance.collection('mesas').doc(tableId).update({
      'width': width / screenSize.width,
      'height': height / screenSize.width,
    });
  }

  void _showEditDialog(
    BuildContext context,
    DocumentSnapshot table,
    Size screenSize,
  ) {
    final tableData = table.data() as Map<String, dynamic>;

    final limits = CardLimits.forScreen(screenSize.width);

    double relativeWidth = (tableData['width'] as num?)?.toDouble() ?? 0.3;
    double relativeHeight = (tableData['height'] as num?)?.toDouble() ?? 0.35;

    double widthInPixels = (relativeWidth * screenSize.width).clamp(limits.minW, limits.maxW);
    double heightInPixels = (relativeHeight * screenSize.width).clamp(limits.minH, limits.maxH);

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
                      min: limits.minW,
                      max: limits.maxW,
                      onChanged:
                          (value) => setState(() => widthInPixels = value),
                    ),
                    Text('Alto: ${heightInPixels.toStringAsFixed(0)}px'),
                    Slider(
                      value: heightInPixels,
                      min: limits.minH,
                      max: limits.maxH,
                      onChanged:
                          (value) => setState(() => heightInPixels = value),
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
                    _updateTableSize(
                      table.id,
                      widthInPixels,
                      heightInPixels,
                      screenSize,
                    );
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
        builder:
            (context) => LogScreen(
              tableId: table.id,
              tableName:
                  (table.data() as Map<String, dynamic>)['nombre'] ?? 'Mesa',
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
                return Center(
                  child: Text('Error al cargar las mesas: ${snapshot.error}'),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text('No hay mesas creadas. Añade una para empezar.'),
                );
              }

              final tables = snapshot.data!.docs;

              return Stack(
                key: _stackKey,
                children:
                    tables.map((table) {
                      final tableData = table.data() as Map<String, dynamic>;

                      final double relativeDx =
                          (tableData['dx'] as num?)?.toDouble() ?? 0.05;
                      final double relativeDy =
                          (tableData['dy'] as num?)?.toDouble() ?? 0.05;

                      final double absoluteDx =
                          relativeDx * availableSize.width;
                      final double absoluteDy =
                          relativeDy * availableSize.height;

                      Widget tableWidget = _TableWidget(
                        table: table,
                        screenSize: availableSize,
                        userRole: widget.userRole,
                        onLogTap: () => _showTableLog(context, table),
                        onLongPress:
                            () =>
                                _showEditDialog(context, table, availableSize),
                      );

                      return Positioned(
                        left: absoluteDx,
                        top: absoluteDy,
                        child: Draggable(
                          feedback: tableWidget,
                          childWhenDragging: Container(),
                          onDragEnd: (details) {
                            final RenderBox stackRenderBox =
                                _stackKey.currentContext!.findRenderObject()
                                    as RenderBox;
                            final localOffset = stackRenderBox.globalToLocal(
                              details.offset,
                            );

                            final tableData =
                                table.data() as Map<String, dynamic>;
                            final double relativeWidth =
                                (tableData['width'] as num?)?.toDouble() ?? 0.3;
                            final double relativeHeight =
                                (tableData['height'] as num?)?.toDouble() ??
                                0.35;
                            final dragLimits = CardLimits.forScreen(availableSize.width);
                            final double cardWidth = (relativeWidth *
                                    availableSize.width)
                                .clamp(dragLimits.minW, dragLimits.maxW);
                            final double cardHeight = (relativeHeight *
                                    availableSize.width)
                                .clamp(dragLimits.minH, dragLimits.maxH);

                            final double maxDx =
                                availableSize.width - cardWidth;
                            final double maxDy =
                                availableSize.height - cardHeight;

                            final double snappedDx =
                                (localOffset.dx / snapGridSize).round() *
                                snapGridSize;
                            final double snappedDy =
                                (localOffset.dy / snapGridSize).round() *
                                snapGridSize;

                            final double clampedDx = snappedDx.clamp(
                              0.0,
                              maxDx,
                            );
                            final double clampedDy = snappedDy.clamp(
                              0.0,
                              maxDy,
                            );

                            FirebaseFirestore.instance
                                .collection('mesas')
                                .doc(table.id)
                                .update({
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
        onPressed:
            () => Navigator.of(context).push(
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
  final String userRole;
  final VoidCallback onLogTap;
  final VoidCallback onLongPress;

  const _TableWidget({
    required this.table,
    required this.screenSize,
    required this.userRole,
    required this.onLogTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final tableData = table.data() as Map<String, dynamic>;

    final double relativeWidth =
        (tableData['width'] as num?)?.toDouble() ?? 0.3;
    final double relativeHeight =
        (tableData['height'] as num?)?.toDouble() ?? 0.35;

    // Calcular límites adaptativos basados en el tipo de dispositivo
    final limits = CardLimits.forScreen(screenSize.width);

    final double widthInPixels = (relativeWidth * screenSize.width).clamp(limits.minW, limits.maxW);
    final double heightInPixels = (relativeHeight * screenSize.width).clamp(limits.minH, limits.maxH);

    // Escalar fuentes y padding según el ancho de pantalla
    final bool isTablet = screenSize.width > 600;
    final double titleFontSize = isTablet ? 18.0 : 14.0;
    final double bodyFontSize = isTablet ? 18.0 : 14.0;
    final double iconSize = isTablet ? 28.0 : 24.0;
    final double headerPadding = isTablet ? 12.0 : 8.0;
    final double borderWidth = isTablet ? 3.0 : 2.5;
    final double borderRadius = isTablet ? 16.0 : 12.0;

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
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (context) => TableDetailScreen(
                    tableId: table.id,
                    tableName: tableName,
                    userRole: userRole,
                  ),
            ),
          ),
      onLongPress: onLongPress,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: widthInPixels,
          height: heightInPixels,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: isTablet
                ? [
                    BoxShadow(
                      color: borderColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: headerPadding),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(borderRadius - 3),
                    topRight: Radius.circular(borderRadius - 3),
                  ),
                ),
                child: Text(
                  tableName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: titleFontSize,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: isTablet ? 4 : 2),
                      Text(
                        '$guestCount ',
                        style: TextStyle(
                          fontSize: bodyFontSize,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      SizedBox(height: isTablet ? 6 : 4),
                    ],
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.receipt_long_outlined, size: iconSize),
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
