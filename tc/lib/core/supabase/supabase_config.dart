import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase client bootstrap.
///
/// **Production:** pass secrets at build time so CI/stores use the right project:
/// `flutter build apk --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...`
///
/// The anon key is not a server secret (it ships in the client) but must match RLS policies per environment.
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://gbhrdqrusignraooaara.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdiaHJkcXJ1c2lnbnJhb29hYXJhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMxMDIyOTYsImV4cCI6MjA4ODY3ODI5Nn0.1FQ-ULiKhBCfC-FlAiSby_YRhzusb_hnB9VzDFfI5Ao',
  );

  static SupabaseClient get client => Supabase.instance.client;

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    final u = url.trim();
    final k = anonKey.trim();
    if (u.isEmpty || k.isEmpty) {
      throw StateError(
        'SupabaseConfig: SUPABASE_URL and SUPABASE_ANON_KEY must be non-empty '
        '(use --dart-define or embedded defaults).',
      );
    }
    await Supabase.initialize(url: u, anonKey: k);
    _initialized = true;
    if (kDebugMode) {
      debugPrint('[SupabaseConfig] initialized url=$u');
    }
  }
}