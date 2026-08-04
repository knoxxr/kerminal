import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/update_providers.dart';
import 'supabase_bootstrap.dart';

/// Thrown when an inquiry could not be delivered. [message] is safe to show.
class FeedbackException implements Exception {
  const FeedbackException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Sends in-app inquiries to the maintainer.
///
/// The message goes to the `send-feedback` Edge Function, which holds the
/// destination address in a server-side secret. The address is deliberately not
/// in the app: a `mailto:` link or a bundled constant would expose it to anyone
/// who installs the app or reads the (public) repository.
class FeedbackService {
  const FeedbackService(this._client);

  final SupabaseClient _client;

  /// Sends [message], optionally with a [contact] address to reply to.
  ///
  /// Returns true when the server also managed to email it; false means the
  /// message was stored but not delivered yet (mail provider trouble) — still a
  /// success for the sender, so the UI reports it as sent either way.
  Future<bool> send({
    required String message,
    String? contact,
    String? platform,
    String? appVersion,
  }) async {
    try {
      final res = await _client.functions.invoke('send-feedback', body: {
        'message': message,
        if (contact != null && contact.trim().isNotEmpty)
          'contact': contact.trim(),
        'platform': ?platform,
        'appVersion': ?appVersion,
      });
      final data = res.data;
      if (data is Map && data['error'] != null) {
        throw FeedbackException('${data['error']}');
      }
      return data is Map && data['delivered'] == true;
    } on FunctionException catch (e) {
      // Surface the function's own error text when it sent one.
      final details = e.details;
      final reason = details is Map && details['error'] != null
          ? '${details['error']}'
          : 'status ${e.status}';
      throw FeedbackException('Could not send your message ($reason).');
    } catch (e) {
      throw FeedbackException('Could not send your message. $e');
    }
  }
}

/// Null in local-only builds (no cloud credentials), where the contact form is
/// hidden — there is no server to relay through.
final feedbackServiceProvider = Provider<FeedbackService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : FeedbackService(client);
});

/// Short platform label attached to an inquiry, so a report is actionable
/// without asking the sender what they were running.
String currentPlatformLabel() {
  if (kIsWeb) return 'web';
  return defaultTargetPlatform.name.toLowerCase();
}

/// `version+build` of the running app, or null while it is still loading.
final appVersionLabelProvider = Provider<String?>((ref) {
  final info = ref.watch(packageInfoProvider).asData?.value;
  return info == null ? null : '${info.version}+${info.buildNumber}';
});
