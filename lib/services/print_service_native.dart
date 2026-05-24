import 'print_service.dart';
import 'print_service_mobile.dart';

/// Crea el PrintService para móvil/Android (impresión directa USB).
PrintService createPrintService() => MobilePrintService();
