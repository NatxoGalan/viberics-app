import 'package:flutter/material.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'print_service.dart';
import 'thermal_printer_service.dart';

/// Implementación móvil: imprime directamente por USB con ESC/POS.
class MobilePrintService extends PrintService {
  @override
  Future<void> printTicket({
    required BuildContext context,
    required String tableName,
    required List<MapEntry<String, dynamic>> items,
    required double total,
    required String userEmail,
  }) async {
    final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final int totalItems = items.fold<int>(
      0,
      (acc, entry) => acc + ((entry.value['cantidad'] as num?)?.toInt() ?? 0),
    );

    // Mostrar indicador de progreso mientras se conecta e imprime
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text('Conectando con la impresora...')),
            ],
          ),
        ),
      );
    }

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      // ===== CABECERA: LOGO VIBÈRICS =====
      bytes += generator.text(
        '· viberics ·',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.feed(1);

      // ===== DATOS DEL NEGOCIO =====
      bytes += generator.text('VIBERICS O.E.',
          styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text('PLAZA MAYOR, 13',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('46450 BENIFAIO',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('Cif. E-55437081',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('Tlf. 699 620 662',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(1);
      bytes += generator.text('Factura proforma',
          styles: const PosStyles(align: PosAlign.center, bold: true));

      bytes += generator.hr();

      // ===== DATOS DE LA MESA Y FECHA =====
      bytes += generator.row([
        PosColumn(text: 'Mesa: $tableName', width: 6,
            styles: const PosStyles(bold: true)),
        PosColumn(text: now, width: 6,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.text('Atendido por: $userEmail',
          styles: const PosStyles(align: PosAlign.left));

      bytes += generator.hr();

      // ===== CABECERA DE PRODUCTOS =====
      bytes += generator.row([
        PosColumn(text: 'Producto', width: 5,
            styles: const PosStyles(bold: true)),
        PosColumn(text: 'Ud.', width: 2,
            styles: const PosStyles(align: PosAlign.center, bold: true)),
        PosColumn(text: 'P/ud', width: 2,
            styles: const PosStyles(align: PosAlign.right, bold: true)),
        PosColumn(text: 'EUR', width: 3,
            styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
      bytes += generator.hr(ch: '-');

      // ===== LISTA DE PRODUCTOS =====
      for (final entry in items) {
        final name = entry.key;
        final data = entry.value;
        final price = (data['precio'] as num?)?.toDouble() ?? 0.0;
        final qty = (data['cantidad'] as num?)?.toInt() ?? 0;
        final subtotal = price * qty;

        bytes += generator.row([
          PosColumn(text: name, width: 5),
          PosColumn(text: '$qty', width: 2,
              styles: const PosStyles(align: PosAlign.center)),
          PosColumn(text: price.toStringAsFixed(2), width: 2,
              styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: subtotal.toStringAsFixed(2), width: 3,
              styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      bytes += generator.hr();

      // ===== TOTAL =====
      bytes += generator.row([
        PosColumn(text: 'Total: $totalItems uds.', width: 6,
            styles: const PosStyles(bold: true, height: PosTextSize.size2)),
        PosColumn(text: '${total.toStringAsFixed(2)} EUR', width: 6,
            styles: const PosStyles(
              align: PosAlign.right,
              bold: true,
              height: PosTextSize.size2,
            )),
      ]);

      bytes += generator.hr();

      // ===== MÉTODO DE PAGO =====
      bytes += generator.row([
        PosColumn(text: 'Metodo de pago', width: 6,
            styles: const PosStyles(bold: true)),
        PosColumn(text: 'EUR', width: 6,
            styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Cash', width: 6),
        PosColumn(text: total.toStringAsFixed(2), width: 6,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Entregado:', width: 6),
        PosColumn(text: total.toStringAsFixed(2), width: 6,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Cambio:', width: 6,
            styles: const PosStyles(bold: true)),
        PosColumn(text: '0,00', width: 6,
            styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);

      bytes += generator.feed(1);

      // ===== PIE DE TICKET =====
      bytes += generator.text('Atendido por: $userEmail',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(1);
      bytes += generator.text('GRACIAS POR SU VISITA',
          styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.feed(2);
      bytes += generator.cut();

      // Enviar directamente a la impresora USB
      final printerService = ThermalPrinterService.instance;
      final printed = await printerService.printData(bytes);

      // Cerrar el diálogo de progreso
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        if (printed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ticket impreso correctamente ✓'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          // Mostrar diálogo con opciones para reintentar o seleccionar impresora
          _showPrinterErrorDialog(context, bytes, printerService);
        }
      }
    } catch (e) {
      // Cerrar el diálogo de progreso si está abierto
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al preparar el ticket: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Muestra un diálogo con información del error y opciones para reintentar
  /// o seleccionar otra impresora manualmente.
  void _showPrinterErrorDialog(
    BuildContext context,
    List<int> bytes,
    ThermalPrinterService printerService,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.print_disabled, color: Colors.red),
            SizedBox(width: 10),
            Text('Error de impresión'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No se pudo conectar con la impresora USB.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('Comprueba que:'),
            const SizedBox(height: 4),
            const Text('• La impresora esté encendida'),
            const Text('• El cable USB esté bien conectado'),
            const Text('• Se haya concedido permiso USB'),
            const SizedBox(height: 12),
            if (printerService.lastError != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  printerService.lastError!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _selectPrinterAndPrint(context, bytes, printerService);
            },
            child: const Text('Buscar impresoras'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              
              // Mostrar progreso
              if (context.mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => const AlertDialog(
                    content: Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 20),
                        Expanded(child: Text('Reintentando...')),
                      ],
                    ),
                  ),
                );
              }

              // Forzar desconexión y reconexión
              await printerService.disconnect();
              final printed = await printerService.printData(bytes);

              if (context.mounted) {
                Navigator.of(context).pop(); // cerrar progreso
                
                if (printed) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ticket impreso correctamente ✓'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  _showPrinterErrorDialog(context, bytes, printerService);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  /// Escanea y muestra una lista de impresoras para que el usuario seleccione.
  void _selectPrinterAndPrint(
    BuildContext context,
    List<int> bytes,
    ThermalPrinterService printerService,
  ) async {
    // Mostrar progreso de escaneo
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text('Buscando impresoras USB...')),
            ],
          ),
        ),
      );
    }

    final printers = await printerService.scanUSBPrinters();

    if (!context.mounted) return;
    Navigator.of(context).pop(); // cerrar progreso

    if (printers.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sin impresoras'),
          content: const Text(
            'No se encontraron impresoras USB.\n\n'
            'Asegúrate de que la impresora está encendida y conectada '
            'por cable USB a la tablet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
      return;
    }

    // Mostrar lista de impresoras encontradas
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Impresoras encontradas (${printers.length})'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: printers.length,
            itemBuilder: (context, index) {
              final printer = printers[index];
              return ListTile(
                leading: const Icon(Icons.print, color: Colors.blue),
                title: Text(printer.name ?? 'Impresora ${index + 1}'),
                subtitle: Text(
                  printer.isConnected == true ? 'Conectada' : 'Disponible',
                  style: TextStyle(
                    color: printer.isConnected == true ? Colors.green : Colors.grey,
                  ),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  
                  // Mostrar progreso
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => AlertDialog(
                        content: Row(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Text('Conectando a ${printer.name ?? "impresora"}...'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final connected = await printerService.connect(printer);

                  if (connected) {
                    final printed = await printerService.printData(bytes);
                    
                    if (context.mounted) {
                      Navigator.of(context).pop(); // cerrar progreso
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            printed
                                ? 'Ticket impreso correctamente ✓'
                                : 'Conectado pero no se pudo imprimir.',
                          ),
                          backgroundColor: printed ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  } else {
                    if (context.mounted) {
                      Navigator.of(context).pop(); // cerrar progreso
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'No se pudo conectar a ${printer.name ?? "la impresora"}',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  @override
  Future<void> printKitchenTicket({
    required BuildContext context,
    required String tableName,
    required Map<String, int> foodItems,
    required String userEmail,
  }) async {
    final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // Mostrar indicador de progreso
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text('Enviando comanda a cocina...')),
            ],
          ),
        ),
      );
    }

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      // ===== CABECERA DE COCINA =====
      bytes += generator.text(
        '*** COCINA ***',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.feed(1);

      bytes += generator.row([
        PosColumn(
            text: 'Mesa: $tableName',
            width: 6,
            styles: const PosStyles(
              bold: true,
              height: PosTextSize.size2,
            )),
        PosColumn(
            text: now,
            width: 6,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.text('Camarero: $userEmail',
          styles: const PosStyles(align: PosAlign.left));
      bytes += generator.hr();

      // ===== LISTA DE COMIDA =====
      for (final entry in foodItems.entries) {
        final name = entry.key;
        final qty = entry.value;

        bytes += generator.row([
          PosColumn(
              text: '$qty x',
              width: 2,
              styles: const PosStyles(
                bold: true,
                height: PosTextSize.size2,
              )),
          PosColumn(
              text: name,
              width: 10,
              styles: const PosStyles(
                bold: true,
                height: PosTextSize.size2,
              )),
        ]);
        bytes += generator.feed(1); // Espacio entre platos para leer mejor
      }

      bytes += generator.hr();
      bytes += generator.feed(2);
      bytes += generator.cut();

      // Enviar directamente a la impresora USB
      final printerService = ThermalPrinterService.instance;
      final printed = await printerService.printData(bytes);

      if (context.mounted) {
        Navigator.of(context).pop(); // Cerrar diálogo progreso

        if (printed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comanda enviada a cocina ✓'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          // Si falla, mostramos el diálogo de error de impresora
          _showPrinterErrorDialog(context, bytes, printerService);
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Cerrar progreso
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al preparar comanda de cocina: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
