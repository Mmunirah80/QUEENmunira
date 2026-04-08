import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../debug/debug_auth_bypass.dart';

/// Supabase client bootstrap.
///
/// **Production:** pass secrets at build time so CI/stores use the right project:
/// `flutter build apk --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...`
///
/// The anon key is not a server secret (it ships in the client) but must match RLS policies per environment.
///
/// **Debug auth bypass + RLS:** pass the project **service role** key only for local QA (never ship to stores):
/// `flutter run --dart-define=SUPABASE_SERVICE_ROLE_KEY=eyJ...`
/// When set with [authBypassIsOn], [dataClient] uses that client so PostgREST/realtime for chat & orders
/// are not blocked by `auth.uid()` RLS. Without it, [dataClient] falls back to the anon [client].
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

  /// Optional service role JWT for **debug bypass only** (see class doc).
  static const String serviceRoleKey = String.fromEnvironment(
    'SUPABASE_SERVICE_ROLE_KEY',
    defaultValue: '',
  );

  static SupabaseClient? _serviceRoleClient;

  static SupabaseClient get client => Supabase.instance.client;

  /// Prefer for chat, orders, and related tables when [authBypassIsOn] and [serviceRoleKey] is set.
  static SupabaseClient get dataClient =>
      (authBypassIsOn && _serviceRoleClient != null) ? _serviceRoleClient! : client;

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
    if (authBypassIsOn) {
      final sr = serviceRoleKey.trim();
      if (sr.isNotEmpty) {
        _serviceRoleClient = SupabaseClient(u, sr);
        if (kDebugMode) {
          debugPrint(
            '[SupabaseConfig] debug bypass: service-role dataClient enabled (chat/orders RLS bypass)',
          );
        }
      } else if (kDebugMode) {
        debugPrint(
          '[SupabaseConfig] debug bypass: SUPABASE_SERVICE_ROLE_KEY empty — '
          'chat/orders may be blocked by RLS. Use dart-define or run '
          'naham/tc/supabase_debug_disable_rls_chat_orders.sql (dev only).',
        );
      }
    }
    _initialized = true;
    if (kDebugMode) {
      debugPrint('[SupabaseConfig] initialized url=$u');
    }
  }
}