import 'print_service.dart';
import 'print_service_web.dart';

/// Crea el PrintService para Web (fallback por defecto).
PrintService createPrintService() => WebPrintService();
