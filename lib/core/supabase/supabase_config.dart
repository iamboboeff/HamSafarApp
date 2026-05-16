/// Ported from `SupabaseConfig` in `SupabaseConfig.swift`.
///
/// The credentials below are the same ones committed in the iOS project and
/// point at the shared production Supabase project.
abstract final class SupabaseConfig {
  static const url = 'https://yixggnwrnlclcrhttzyo.supabase.co';

  /// The SwiftUI client is initialised with the publishable key, so the
  /// Flutter client uses the same one.
  static const publishableKey = 'sb_publishable_OkL_8km1-VLBvm4qUkkU9w_9eztUZn3';

  static const functionsBaseUrl =
      'https://yixggnwrnlclcrhttzyo.supabase.co/functions/v1';
  static const pushDispatchFunctionPath = 'smart-function';
  static const contactIntakeFunctionPath = 'contact--intake';
}
