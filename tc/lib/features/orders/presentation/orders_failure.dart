import '../../../core/utils/supabase_error_message.dart';
import '../data/datasources/orders_datasource_exceptions.dart';

/// Orders-layer errors use [OrdersDataSourceException.message]; everything else uses [userFriendlyErrorMessage].
String resolveOrdersUiError(Object error, {String? fallback}) {
  if (error is OrdersDataSourceException) return error.message;
  return userFriendlyErrorMessage(
    error,
    fallback: fallback ?? 'Something went wrong. Please try again.',
  );
}

/// Maps [AsyncValue.error] / stream errors to an offline-specific banner when appropriate.
bool ordersErrorIsOffline(Object error) =>
    error is OrdersOfflineException || ordersDataSourceLooksLikeOffline(error);

bool ordersErrorIsAuth(Object error) => error is OrdersAuthException;

bool ordersErrorIsRateLimit(Object error) => error is OrdersRateLimitException;

bool ordersErrorIsConcurrency(Object error) => error is OrderConcurrencyException;

/// Copy-safe message for snackbars and error panels (same resolution as UI).
String ordersErrorUserMessage(Object error) => resolveOrdersUiError(error);
