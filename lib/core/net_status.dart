import 'dart:async';
import 'dart:io';

/// Best-effort detection of "we're offline / can't reach the backend" errors.
///
/// The app has no connectivity plugin, so we infer it from the failures the
/// Supabase/HTTP/auth stack throws when the network is down: socket failures,
/// host-lookup failures, request timeouts, and gotrue's retryable fetch error.
/// Used to show a clear "no internet" message instead of an endless spinner or
/// an empty result set (QA #59, #92).
bool isOfflineError(Object error) {
  if (error is SocketException || error is TimeoutException) return true;

  final type = error.runtimeType.toString().toLowerCase();
  if (type.contains('clientexception') ||
      type.contains('retryablefetch') ||
      type.contains('socketexception')) {
    return true;
  }

  final message = error.toString().toLowerCase();
  const needles = [
    'failed host lookup',
    'no address associated with hostname',
    'network is unreachable',
    'connection refused',
    'connection closed',
    'connection reset',
    'connection failed',
    'connection timed out',
    'operation timed out',
    'software caused connection abort',
    'timeout',
    'socketexception',
  ];
  return needles.any(message.contains);
}

/// Standard user-facing message for offline failures.
const String offlineMessage =
    'Нет подключения к интернету. Проверьте соединение и попробуйте снова.';
