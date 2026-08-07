import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/account_providers.dart';
import '../../application/providers.dart';

/// Account screen: sign up / sign in, unlock with the encryption passphrase, and
/// show the signed-in account. Cloud sync/sharing is layered on later phases.
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Account & Sync')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (account) => switch (account) {
            AccountCloudDisabled() => const _CloudDisabledView(),
            AccountSignedOut() => const _AuthForm(),
            AccountLocked(:final email) => _UnlockView(email: email),
            AccountUnlocked(:final identity) =>
              _SignedInView(email: identity.email),
          },
        ),
      ),
    );
  }
}

class _CloudDisabledView extends StatelessWidget {
  const _CloudDisabledView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Cloud sync is not configured in this build.\n\n'
        'Provide SUPABASE_URL and SUPABASE_ANON_KEY at build time '
        '(--dart-define) to enable accounts, sync, and sharing.',
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Sign in / sign up form.
class _AuthForm extends ConsumerStatefulWidget {
  const _AuthForm();

  @override
  ConsumerState<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends ConsumerState<_AuthForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passphrase = TextEditingController();
  bool _signUp = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passphrase.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = ref.read(accountControllerProvider.notifier);
    setState(() => _busy = true);
    try {
      if (_signUp) {
        if (_passphrase.text.isEmpty) {
          throw const AccountException('Set an encryption passphrase.');
        }
        await controller.signUp(
          email: _email.text.trim(),
          password: _password.text,
          passphrase: _passphrase.text,
        );
      } else {
        await controller.signIn(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Sign in')),
            ButtonSegment(value: true, label: Text('Sign up')),
          ],
          selected: {_signUp},
          onSelectionChanged: (s) => setState(() => _signUp = s.first),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Account password',
            helperText: 'For signing in',
          ),
        ),
        if (_signUp) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _passphrase,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Encryption passphrase',
              helperText: 'A second, separate secret that encrypts your servers '
                  'on this device before they are uploaded. We never receive it, '
                  'so if you lose it your synced servers cannot be recovered.',
              helperMaxLines: 4,
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_signUp ? 'Create account' : 'Sign in'),
        ),
      ],
    );
  }
}

/// Passphrase unlock (signed in, key still locked).
class _UnlockView extends ConsumerStatefulWidget {
  const _UnlockView({required this.email});
  final String email;

  @override
  ConsumerState<_UnlockView> createState() => _UnlockViewState();
}

class _UnlockViewState extends ConsumerState<_UnlockView> {
  final _passphrase = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _passphrase.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(accountControllerProvider.notifier)
          .unlock(_passphrase.text);
    } on MissingEncryptionKeyException {
      // Not a wrong passphrase — there is nothing to unlock yet. Setting a key
      // up is destructive for anything encrypted under a previous one, so ask.
      if (mounted) await _offerToCreateKey();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wrong passphrase.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _offerToCreateKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.key),
        title: const Text('Set up encryption for this account?'),
        content: const Text(
          'This account has no encryption key yet, so there is nothing to '
          'decrypt with a passphrase.\n\n'
          'Creating one now uses the passphrase you just typed. If this account '
          'previously had a key, anything already synced — including servers '
          'colleagues shared with you — will no longer be readable.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create key'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(accountControllerProvider.notifier)
          .createEncryptionKey(_passphrase.text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not set up: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text('Signed in as ${widget.email}'),
        const SizedBox(height: 8),
        Text(
          'Enter your encryption passphrase to decrypt your synced servers on '
          'this device. This is the second secret you chose when signing up — '
          'not your account password.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _passphrase,
          obscureText: true,
          autofocus: true,
          onSubmitted: (_) => _unlock(),
          decoration: const InputDecoration(labelText: 'Encryption passphrase'),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _unlock,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Decrypt my servers'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () =>
              ref.read(accountControllerProvider.notifier).signOut(),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}

/// Signed in and unlocked.
class _SignedInView extends ConsumerWidget {
  const _SignedInView({required this.email});
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.verified_user_outlined),
          title: Text(email),
          subtitle: const Text('Signed in · servers decrypted on this device'),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final sync = ref.read(hostSyncServiceProvider);
            if (sync == null) return;
            messenger.showSnackBar(
              const SnackBar(content: Text('Syncing…')),
            );
            try {
              final result = await sync.reconcile();
              ref.read(shareInfoProvider.notifier).set(result.shareInfo);
              final skipped = result.undecryptableHostIds.length;
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    skipped == 0
                        ? 'Servers synced.'
                        : 'Servers synced — $skipped could not be decrypted '
                            'and were skipped.',
                  ),
                ),
              );
            } catch (e) {
              messenger.showSnackBar(SnackBar(content: Text('Sync failed: $e')));
            }
          },
          icon: const Icon(Icons.sync),
          label: const Text('Sync servers now'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () =>
              ref.read(accountControllerProvider.notifier).signOut(),
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}
