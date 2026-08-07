import 'package:flutter/material.dart';

import '../../core/router/app_router.dart';
import '../../data/ssh/ssh_service.dart';

/// Builds the responder for keyboard-interactive authentication — the method
/// servers use for one-time codes, expired passwords and similar challenges.
///
/// The server decides what to ask, so the dialog is generated from its prompts
/// rather than hard-coded. Uses the root navigator, like the host-key prompt,
/// because authentication happens below the widget tree.
SshUserInfoResponder buildUserInfoResponder() {
  return (name, instruction, prompts) async {
    // Some servers send a round with no prompts, just to display a banner.
    // Answer with an empty list so authentication continues — no UI needed,
    // and checked before the context so it works even without a navigator.
    if (prompts.isEmpty) return const <String>[];

    final context = rootNavigatorKey.currentContext;
    if (context == null) return null;

    return showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UserInfoDialog(
        name: name,
        instruction: instruction,
        prompts: prompts,
      ),
    );
  };
}

class _UserInfoDialog extends StatefulWidget {
  const _UserInfoDialog({
    required this.name,
    required this.instruction,
    required this.prompts,
  });

  final String name;
  final String instruction;
  final List<SshPrompt> prompts;

  @override
  State<_UserInfoDialog> createState() => _UserInfoDialogState();
}

class _UserInfoDialogState extends State<_UserInfoDialog> {
  late final List<TextEditingController> _answers;

  @override
  void initState() {
    super.initState();
    _answers = [
      for (var i = 0; i < widget.prompts.length; i++) TextEditingController(),
    ];
  }

  @override
  void dispose() {
    for (final c in _answers) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() =>
      Navigator.pop(context, [for (final c in _answers) c.text]);

  @override
  Widget build(BuildContext context) {
    final title = widget.name.trim().isEmpty
        ? 'The server needs more information'
        : widget.name.trim();
    return AlertDialog(
      icon: const Icon(Icons.pin_outlined),
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.instruction.trim().isNotEmpty) ...[
              Text(widget.instruction.trim()),
              const SizedBox(height: 12),
            ],
            for (var i = 0; i < widget.prompts.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              TextField(
                controller: _answers[i],
                autofocus: i == 0,
                // The server says whether the answer is a secret.
                obscureText: !widget.prompts[i].echo,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: widget.prompts[i].text.trim(),
                  border: const OutlineInputBorder(),
                ),
                // Single-prompt challenges (the common OTP case) submit on enter.
                onSubmitted:
                    widget.prompts.length == 1 ? (_) => _submit() : null,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          // Null tells dartssh2 to abandon this authentication method.
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Continue')),
      ],
    );
  }
}
