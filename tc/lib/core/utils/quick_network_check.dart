import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../supabase/supabase_config.dart';

/// Lightweight reachability before registration steps.
///
/// Native: DNS lookup. Web: short HTTP request to the app [SupabaseConfig.url] (same host real traffic uses).
/// This does not guarantee the full API works; it filters obvious offline cases.
Future<String?> quickNetworkCheckMessage() async {
  if (kIsWeb) {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
          validateStatus: (_) => true,
        ),
      );
      await dio.get<Object>(SupabaseConfig.url);
      return null;
    } catch (_) {
      return 'No internet connection. Check your network and try again.';
    }
  }
  try {
    await InternetAddress.lookup('example.com').timeout(const Duration(seconds: 4));
    return null;
  } on SocketException {
    return 'No internet connection. Check your network and try again.';
  } on TimeoutException {
    return 'Network check timed out. Try again when you have a stable connection.';
  } catch (_) {
    return 'Could not verify connectivity. Try again when you are online.';
  }
}
