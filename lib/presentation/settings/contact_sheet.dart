import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/remote/feedback_service.dart';

/// Opens the inquiry form. Does nothing when the build has no cloud
/// credentials, since there is no relay to send through.
Future<void> showContactSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ContactSheet(),
    );

class _ContactSheet extends ConsumerStatefulWidget {
  const _ContactSheet();

  @override
  ConsumerState<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends ConsumerState<_ContactSheet> {
  final _message = TextEditingController();
  final _contact = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final service = ref.read(feedbackServiceProvider);
    if (service == null) return;

    setState(() {
      _sending = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final delivered = await service.send(
        message: _message.text,
        contact: _contact.text,
        platform: currentPlatformLabel(),
        appVersion: ref.read(appVersionLabelProvider),
      );
      if (!mounted) return;
      Navigator.pop(context);
      // Claiming "sent" when the server could not email it would be a lie the
      // user only discovers by never getting a reply.
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            delivered
                ? 'Thanks — your message was sent.'
                : 'Your message was received, but email delivery is currently '
                    'failing. If you get no reply, please open a GitHub issue.',
          ),
          duration: Duration(seconds: delivered ? 4 : 8),
        ),
      );
    } on FeedbackException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      // Keeps the fields above the soft keyboard on phones.
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: 24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contact us', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Questions, bug reports and requests all land with the '
              'maintainer. Add an email if you would like a reply.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _message,
              autofocus: true,
              minLines: 4,
              maxLines: 8,
              maxLength: 5000,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Message',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().length < 5)
                  ? 'Please write a little more'
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _contact,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Your email (optional)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return null;
                return s.contains('@') ? null : 'Not a valid email address';
              },
            ),
            const SizedBox(height: 6),
            Text(
              'Sent with your platform and app version so issues can be '
              'reproduced. Nothing else — no hosts, credentials or terminal '
              'output is included.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _sending ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, size: 18),
                  label: Text(_sending ? 'Sending…' : 'Send'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
