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

  /// Escanea impresoras USB disponibles.
  /// Devuelve la lista de impresoras encontradas.
  Future<List<Printer>> scanUSBPrinters() async {
    final completer = Completer<List<Printer>>();

    _subscription?.cancel();
    await _plugin.getPrinters(connectionTypes: [ConnectionType.USB]);

    _subscription = _plugin.devicesStream.listen((List<Printer> printers) {
      _availablePrinters = printers;
      if (!completer.isCompleted) {
        completer.complete(printers);
      }
    });

    // Esperar máximo 3 segundos para detectar impresoras
    return completer.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () => _availablePrinters,
    );
  }

  /// Conectar a una impresora específica.
  Future<bool> connect(Printer printer) async {
    try {
      await _plugin.connect(printer);
      _connectedPrinter = printer;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Conectar automáticamente a la primera impresora USB disponible.
  Future<bool> autoConnect() async {
    if (isConnected) return true;

    final printers = await scanUSBPrinters();
    if (printers.isEmpty) return false;

    return connect(printers.first);
  }

  /// Imprimir datos ESC/POS directamente.
  Future<bool> printData(List<int> bytes) async {
    if (_connectedPrinter == null) {
      // Intentar auto-conectar
      final connected = await autoConnect();
      if (!connected) return false;
    }

    try {
      await _plugin.printData(
        _connectedPrinter!,
        bytes,
        longData: true,
      );
      return true;
    } catch (e) {
      return false;
    }
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
