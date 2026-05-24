import 'package:flutter/material.dart';
import 'print_service_stub.dart'
    if (dart.library.io) 'print_service_native.dart'
    as platform_impl;

/// Obtiene la implementación de PrintService correcta para la plataforma actual.
/// - Web: usa PDF + diálogo del sistema (printing package).
/// - Android: usa ESC/POS directo por USB (flutter_thermal_printer).
PrintService getPrintService() => platform_impl.createPrintService();

/// Interfaz abstracta del servicio de impresión.
abstract class PrintService {
  Future<void> printTicket({
    required BuildContext context,
    required String tableName,
    required List<MapEntry<String, dynamic>> items,
    required double total,
    required String userEmail,
  });
}
