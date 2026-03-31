import 'package:supabase_flutter/supabase_flutter.dart';

/// Converts Supabase/PostgREST and other API errors into short, user-friendly messages.
String userFriendlyErrorMessage(Object error, {String fallback = 'Something went wrong. Please try again.'}) {
  if (error is PostgrestException) {
    return _fromPostgrest(error, fallback: fallback);
  }

  final raw = error.toString();
  final msg = raw.toLowerCase();

  bool has(String s) => msg.contains(s);

  if (has('socket') ||
      has('timeout') ||
      has('connection') ||
      has('network') ||
      has('failed host lookup') ||
      has('handshake')) {
    return 'Network problem — check your connection and try again.';
  }
  if (has('jwt') || has('401') || has('unauthorized') || has('session') || has('not authenticated')) {
    return 'Session expired — sign out and sign in again.';
  }

  var text = raw;
  if (text.startsWith('Exception: ')) {
    text = text.substring(11);
  }
  if (text.length <= 140) {
    return text;
  }
  return fallback;
}

String _fromPostgrest(PostgrestException e, {required String fallback}) {
  final code = (e.code ?? '').toLowerCase();
  final message = (e.message).trim();
  final details = (e.details?.toString() ?? '').toLowerCase();
  final hint = (e.hint?.toString() ?? '').toLowerCase();
  final combined = '$message $details $hint'.toLowerCase();

  if (code == '429' || combined.contains('rate limit')) {
    return 'Too many requests — wait a moment and try again.';
  }
  if (code == '401' || code == '403') {
    return 'Session expired or not allowed — sign in again.';
  }
  if (code == '42501' ||
      combined.contains('row-level security') ||
      combined.contains('rls') ||
      combined.contains('permission denied') ||
      combined.contains('policy')) {
    return 'The server blocked this action (permissions). Sign out and sign in again, or contact support if it continues.';
  }
  if (code == '23503' || combined.contains('foreign key') || combined.contains('violates foreign key')) {
    return 'Data could not be saved (account link). Make sure you are signed in with the same account type the app expects.';
  }
  if (code == '23505' || combined.contains('unique constraint') || combined.contains('duplicate key')) {
    return 'This was already saved — try again or refresh the screen.';
  }
  if (code == '406' || (combined.contains('multiple') && combined.contains('rows'))) {
    return 'Data mismatch on server (duplicate records). Try again; if it continues, contact support.';
  }
  if (combined.contains('transition') ||
      combined.contains('invalid status') ||
      combined.contains('order_status') ||
      code == 'p0001') {
    if (message.isNotEmpty && message.length < 200) {
      return message;
    }
    return 'This order cannot be changed right now. Open Orders for the latest status.';
  }
  if (message.isNotEmpty && message.length < 200) {
    return message;
  }
  return fallback;
}
