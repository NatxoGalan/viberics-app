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
  /// Imprime el ticket de factura completo (con precios y total).
  Future<void> printTicket({
    required BuildContext context,
    required String tableName,
    required List<MapEntry<String, dynamic>> items,
    required double total,
    required String userEmail,
  });

  /// Imprime un ticket de cocina (solo comida, sin precios).
  /// [foodItems] es un mapa nombre→cantidad de los platos añadidos.
  /// Devuelve `true` si la comanda se imprimió correctamente.
  Future<bool> printKitchenTicket({
    required BuildContext context,
    required String tableName,
    required Map<String, int> foodItems,
    required String userEmail,
  });
}
