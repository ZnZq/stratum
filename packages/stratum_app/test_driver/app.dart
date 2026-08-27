import 'package:flutter_driver/driver_extension.dart';
import 'package:stratum_app/main.dart' as app;

/// Entrypoint for assisted sessions: the real app plus the driver extension,
/// so taps and finders can be driven from outside. Run with
/// `flutter run -d windows -t test_driver/app.dart`.
void main() {
  enableFlutterDriverExtension();
  app.main();
}
