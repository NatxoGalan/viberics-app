import 'dart:async';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';

/// Servicio singleton para gestionar la impresora térmica USB.
/// Se conecta automáticamente a la primera impresora USB detectada.
class ThermalPrinterService {
  ThermalPrinterService._();
  static final ThermalPrinterService instance = ThermalPrinterService._();

  final _plugin = FlutterThermalPrinter.instance;
  StreamSubscription<List<Printer>>? _subscription;

  Printer? _connectedPrinter;
  Printer? get connectedPrinter => _connectedPrinter;
  bool get isConnected => _connectedPrinter?.isConnected == true;

  List<Printer> _availablePrinters = [];
  List<Printer> get availablePrinters => _availablePrinters;

  /// Último error registrado para depuración.
  String? _lastError;
  String? get lastError => _lastError;

  /// Escanea impresoras USB disponibles.
  /// Devuelve la lista de impresoras encontradas.
  Future<List<Printer>> scanUSBPrinters() async {
    final completer = Completer<List<Printer>>();

    _subscription?.cancel();
    _subscription = null;

    try {
      await _plugin.getPrinters(connectionTypes: [ConnectionType.USB]);
    } catch (e) {
      _lastError = 'Error al escanear: $e';
      return [];
    }

    _subscription = _plugin.devicesStream.listen((List<Printer> printers) {
      _availablePrinters = printers;
      if (!completer.isCompleted) {
        completer.complete(printers);
      }
    });

    // Esperar máximo 5 segundos para detectar impresoras (antes eran 3)
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => _availablePrinters,
    );
  }

  /// Conectar a una impresora específica.
  Future<bool> connect(Printer printer) async {
    try {
      await _plugin.connect(printer);
      _connectedPrinter = printer;
      _lastError = null;
      return true;
    } catch (e) {
      _lastError = 'Error al conectar: $e';
      return false;
    }
  }

  /// Conectar automáticamente a la primera impresora USB disponible.
  /// Si ya hay una conectada, la desconecta primero para forzar re-detección.
  Future<bool> autoConnect() async {
    // Si ya está conectada, intentar usarla directamente
    if (isConnected) return true;

    // Desconectar cualquier impresora previa que haya perdido la conexión
    if (_connectedPrinter != null) {
      await disconnect();
    }

    final printers = await scanUSBPrinters();
    if (printers.isEmpty) {
      _lastError = 'No se encontraron impresoras USB conectadas.';
      return false;
    }

    // Intentar conectar con la primera impresora encontrada
    final connected = await connect(printers.first);
    if (!connected) {
      _lastError = 'Impresora encontrada pero no se pudo conectar: ${printers.first.name}';
    }
    return connected;
  }

  /// Imprimir datos ESC/POS directamente.
  /// Reintenta la conexión si falla la primera vez.
  Future<bool> printData(List<int> bytes) async {
    // Primer intento
    if (!isConnected) {
      final connected = await autoConnect();
      if (!connected) return false;
    }

    try {
      await _plugin.printData(
        _connectedPrinter!,
        bytes,
        longData: true,
      );
      _lastError = null;
      return true;
    } catch (e) {
      _lastError = 'Error al imprimir (intento 1): $e';

      // Segundo intento: desconectar, reconectar e intentar de nuevo
      await disconnect();
      final reconnected = await autoConnect();
      if (!reconnected) {
        _lastError = 'No se pudo reconectar tras el fallo de impresión.';
        return false;
      }

      try {
        await _plugin.printData(
          _connectedPrinter!,
          bytes,
          longData: true,
        );
        _lastError = null;
        return true;
      } catch (e2) {
        _lastError = 'Error al imprimir (intento 2): $e2';
        return false;
      }
    }
  }

  /// Obtener estado detallado para depuración.
  String getStatus() {
    final parts = <String>[];
    parts.add('Conectada: ${isConnected ? "Sí" : "No"}');
    if (_connectedPrinter != null) {
      parts.add('Impresora: ${_connectedPrinter!.name ?? "Sin nombre"}');
    }
    parts.add('Impresoras disponibles: ${_availablePrinters.length}');
    if (_lastError != null) {
      parts.add('Último error: $_lastError');
    }
    return parts.join('\n');
  }

  /// Desconectar la impresora.
  Future<void> disconnect() async {
    if (_connectedPrinter != null) {
      try {
        await _plugin.disconnect(_connectedPrinter!);
      } catch (_) {}
      _connectedPrinter = null;
    }
    _subscription?.cancel();
    _subscription = null;
  }

  /// Detener escaneo.
  void stopScan() {
    _plugin.stopScan();
    _subscription?.cancel();
    _subscription = null;
  }
}
