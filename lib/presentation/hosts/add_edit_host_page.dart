import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../data/ssh/key_generator.dart';
import '../../domain/entities/host.dart';

/// Create or edit a saved host. Secrets entered here are written to the secure
/// vault by [HostService]; only non-secret metadata reaches the database.
class AddEditHostPage extends ConsumerStatefulWidget {
  const AddEditHostPage({this.existing, super.key});

  final Host? existing;

  bool get isEditing => existing != null;

  @override
  ConsumerState<AddEditHostPage> createState() => _AddEditHostPageState();
}

class _AddEditHostPageState extends ConsumerState<AddEditHostPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _label;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _user;
  late final TextEditingController _group;
  final _password = TextEditingController();
  final _privateKey = TextEditingController();
  final _passphrase = TextEditingController();

  late AuthMethod _authMethod;
  bool _obscure = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _label = TextEditingController(text: e?.label ?? '');
    _host = TextEditingController(text: e?.hostname ?? '');
    _port = TextEditingController(text: (e?.port ?? 22).toString());
    _user = TextEditingController(text: e?.username ?? '');
    _group = TextEditingController(text: e?.groupName ?? '');
    _authMethod = e?.authMethod ?? AuthMethod.password;
  }

  @override
  void dispose() {
    for (final c in [
      _label,
      _host,
      _port,
      _user,
      _group,
      _password,
      _privateKey,
      _passphrase,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(hostServiceProvider).saveHost(
            existing: widget.existing,
            label: _label.text.trim(),
            hostname: _host.text.trim(),
            port: int.parse(_port.text.trim()),
            username: _user.text.trim(),
            groupName: _group.text.trim(),
            authMethod: _authMethod,
            password: _password.text,
            privateKeyPem: _privateKey.text,
            passphrase: _passphrase.text,
          );
      if (mounted) context.goNamed('hosts');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  Future<void> _generateKey() async {
    final comment = _user.text.trim().isEmpty
        ? 'kerminal'
        : '${_user.text.trim()}@kerminal';
    final key = const SshKeyGenerator().generateEd25519(comment: comment);
    setState(() => _privateKey.text = key.privateKeyPem);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Key generated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The private key was filled in below. Install this public key '
              "on the server's ~/.ssh/authorized_keys:",
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                key.publicKeyLine,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: key.publicKeyLine));
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy public key'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.isEditing;
    final secretHint =
        editing ? 'Leave blank to keep the saved secret' : null;

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit Host' : 'Add Host')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _label,
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'Prod web',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _host,
                    decoration: const InputDecoration(
                      labelText: 'Host',
                      hintText: 'example.com',
                    ),
                    autocorrect: false,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _port,
                    decoration: const InputDecoration(labelText: 'Port'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v?.trim() ?? '');
                      if (n == null || n < 1 || n > 65535) return '1-65535';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _user,
              decoration: const InputDecoration(
                labelText: 'Username (optional)',
                hintText: 'Defaults to the current user',
              ),
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _group,
              decoration: const InputDecoration(
                labelText: 'Group (optional)',
                hintText: 'Production',
              ),
            ),
            const SizedBox(height: 20),
            SegmentedButton<AuthMethod>(
              segments: const [
                ButtonSegment(
                  value: AuthMethod.password,
                  label: Text('Password'),
                  icon: Icon(Icons.password),
                ),
                ButtonSegment(
                  value: AuthMethod.sshKey,
                  label: Text('SSH Key'),
                  icon: Icon(Icons.key),
                ),
              ],
              selected: {_authMethod},
              onSelectionChanged: (s) => setState(() => _authMethod = s.first),
            ),
            const SizedBox(height: 16),
            if (_authMethod == AuthMethod.password)
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: secretHint,
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) {
                  if (!editing && (v == null || v.isEmpty)) {
                    return 'Enter a password';
                  }
                  return null;
                },
              )
            else ...[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _generateKey,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generate Ed25519 key'),
                ),
              ),
              TextFormField(
                controller: _privateKey,
                decoration: InputDecoration(
                  labelText: 'Private key (PEM)',
                  hintText: secretHint ??
                      '-----BEGIN OPENSSH PRIVATE KEY-----',
                  alignLabelWithHint: true,
                ),
                minLines: 4,
                maxLines: 8,
                validator: (v) {
                  if (!editing && (v == null || v.trim().isEmpty)) {
                    return 'Paste a private key';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passphrase,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Passphrase (optional)',
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(editing ? 'Save changes' : 'Add host'),
            ),
          ],
        ),
      ),
    );
  }
}
