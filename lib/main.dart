import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/supabase/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU');
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.publishableKey,
  );
  // Android uses Firebase Cloud Messaging for push; iOS goes through the
  // native APNs MethodChannel in `AppDelegate.swift` and intentionally does
  // not initialise Firebase. `Firebase.initializeApp()` with no options
  // reads `google-services.json` via the `com.google.gms.google-services`
  // gradle plugin.
  if (!kIsWeb && Platform.isAndroid) {
    await Firebase.initializeApp();
  }
  runApp(const ProviderScope(child: HamSafarApp()));
}
