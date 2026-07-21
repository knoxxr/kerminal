import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/known_hosts.dart';
import '../../application/sessions.dart';
import '../../core/os_user.dart';
import '../../domain/entities/ssh_connection_request.dart';
import '../terminal/host_key_prompt.dart';

/// Ad-hoc connection form. Lets the user connect to a server without saving it
/// first. Opens the connection as a new terminal tab.
class QuickConnectPage extends ConsumerStatefulWidget {
  const QuickConnectPage({this.prefill, super.key});

  final SshConnectionRequest? prefill;

  @override
  ConsumerState<QuickConnectPage> createState() => _QuickConnectPageState();
}

class _QuickConnectPageState extends ConsumerState<QuickConnectPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _user;
  final _password = TextEditingController();
  final _privateKey = TextEditingController();
  final _passphrase = TextEditingController();

  SshAuthKind _authKind = SshAuthKind.password;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    _host = TextEditingController(text: p?.host ?? '');
    _port = TextEditingController(text: (p?.port ?? 22).toString());
    _user = TextEditingController(text: p?.username ?? '');
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _user.dispose();
    _password.dispose();
    _privateKey.dispose();
    _passphrase.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final user = _user.text.trim();
    final request = SshConnectionRequest(
      host: _host.text.trim(),
      port: int.parse(_port.text.trim()),
      username: user.isEmpty ? osUsername() : user,
      authKind: _authKind,
      password: _authKind == SshAuthKind.password ? _password.text : null,
      privateKeyPem: _authKind == SshAuthKind.key ? _privateKey.text : null,
      passphrase: _authKind == SshAuthKind.key ? _passphrase.text : null,
    );

    ref.read(sessionsProvider.notifier).open(
          request,
          verifyHostKey: buildHostKeyVerifier(ref.read(knownHostsProvider)),
        );
    context.goNamed('terminal');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Connect')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
            const SizedBox(height: 20),
            SegmentedButton<SshAuthKind>(
              segments: const [
                ButtonSegment(
                  value: SshAuthKind.password,
                  label: Text('Password'),
                  icon: Icon(Icons.password),
                ),
                ButtonSegment(
                  value: SshAuthKind.key,
                  label: Text('SSH Key'),
                  icon: Icon(Icons.key),
                ),
              ],
              selected: {_authKind},
              onSelectionChanged: (s) => setState(() => _authKind = s.first),
            ),
            const SizedBox(height: 16),
            if (_authKind == SshAuthKind.password)
              TextFormField(
                controller: _password,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              )
            else ...[
              TextFormField(
                controller: _privateKey,
                decoration: const InputDecoration(
                  labelText: 'Private key (PEM)',
                  hintText: '-----BEGIN OPENSSH PRIVATE KEY-----',
                  alignLabelWithHint: true,
                ),
                minLines: 4,
                maxLines: 8,
                validator: (v) => (_authKind == SshAuthKind.key &&
                        (v == null || v.trim().isEmpty))
                    ? 'Paste a private key'
                    : null,
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
              onPressed: _submit,
              icon: const Icon(Icons.terminal),
              label: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }
}
