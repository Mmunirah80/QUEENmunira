import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Failures from [OrdersSupabaseDataSource] / orders remote layer.
/// UI reads [message] for copy; uses `is` checks for offline / not found / conflicts.
class OrdersDataSourceException implements Exception {
  OrdersDataSourceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'OrdersDataSourceException: $message';
}

class OrdersOfflineException extends OrdersDataSourceException {
  OrdersOfflineException([Object? cause])
      : super(
          'No network connection. Check your connection and try again.',
          cause,
        );
}

/// Missing row or not visible under current chef/customer scope (same message).
class OrderNotFoundException extends OrdersDataSourceException {
  OrderNotFoundException() : super('Order not found.');
}

/// Optimistic concurrency or invalid transition (0 rows updated).
class OrderConcurrencyException extends OrdersDataSourceException {
  OrderConcurrencyException([Object? cause])
      : super(
          'This order changed on the server. Refresh and try again.',
          cause,
        );
}

class OrdersScopeException extends OrdersDataSourceException {
  OrdersScopeException(String message, [Object? cause]) : super(message, cause);
}

/// Session expired or not authorized (JWT / RLS). User must re-authenticate.
class OrdersAuthException extends OrdersDataSourceException {
  OrdersAuthException([Object? cause])
      : super(
          'Your session expired. Sign in again to continue.',
          cause,
        );
}

/// Upstream throttling (real APIs under load).
class OrdersRateLimitException extends OrdersDataSourceException {
  OrdersRateLimitException([Object? cause])
      : super(
          'Too many requests. Wait a moment and try again.',
          cause,
        );
}

bool ordersDataSourceLooksLikeOffline(Object error) {
  if (error is TimeoutException) return true;
  if (error is OrdersOfflineException) return true;
  if (error is PostgrestException) {
    final code = (error.code ?? '').trim();
    if (code == '503' || code == '504') return true;
    final m = error.message.toLowerCase();
    if (m.contains('network') ||
        m.contains('socket') ||
        m.contains('failed host lookup') ||
        m.contains('connection refused') ||
        m.contains('timed out') ||
        m.contains('timeout')) {
      return true;
    }
  }
  final s = error.toString().toLowerCase();
  return s.contains('socketexception') ||
      s.contains('failed host lookup') ||
      s.contains('connection refused') ||
      s.contains('network is unreachable');
}

Never ordersDataSourceRethrowMapped(Object error, StackTrace st, String context) {
  if (error is OrdersDataSourceException) {
    Error.throwWithStackTrace(error, st);
  }
  if (ordersDataSourceLooksLikeOffline(error)) {
    Error.throwWithStackTrace(OrdersOfflineException(error), st);
  }
  if (error is PostgrestException) {
    final code = (error.code ?? '').trim();
    final msg = error.message.toLowerCase();
    if (code == '401' ||
        code == '403' ||
        msg.contains('jwt') ||
        msg.contains('permission denied') ||
        msg.contains('not authorized')) {
      Error.throwWithStackTrace(OrdersAuthException(error), st);
    }
    if (code == '429' || msg.contains('rate limit')) {
      Error.throwWithStackTrace(OrdersRateLimitException(error), st);
    }
    Error.throwWithStackTrace(
      OrdersDataSourceException(
        '$context: ${error.message}',
        error,
      ),
      st,
    );
  }
  Error.throwWithStackTrace(
    OrdersDataSourceException('$context: $error', error),
    st,
  );
}
