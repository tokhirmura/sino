import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/backend/backend.dart';

/// Run: flutter run --dart-define-from-file=env.json
/// Fake (offline): flutter run   (or --dart-define=USE_FAKE=true)
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  final prefs = await SharedPreferences.getInstance();
  await Backend.init();
  runApp(
    ProviderScope(
      overrides: appOverrides(prefs: prefs),
      child: const SinoApp(),
    ),
  );
}
