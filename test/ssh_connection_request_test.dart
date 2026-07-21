import 'package:flutter_test/flutter_test.dart';
import 'package:kominal/application/ssh_terminal_controller.dart';
import 'package:kominal/domain/entities/ssh_connection_request.dart';

void main() {
  group('SshConnectionRequest.displayName', () {
    test('uses label when present', () {
      const req = SshConnectionRequest(
        host: 'example.com',
        port: 22,
        username: 'root',
        authKind: SshAuthKind.password,
        label: 'Prod web',
      );
      expect(req.displayName, 'Prod web');
    });

    test('falls back to user@host:port when label is empty', () {
      const req = SshConnectionRequest(
        host: 'example.com',
        port: 2222,
        username: 'root',
        authKind: SshAuthKind.password,
        label: '',
      );
      expect(req.displayName, 'root@example.com:2222');
    });
  });

  test('SshTerminalController starts idle', () {
    final controller = SshTerminalController();
    addTearDown(controller.dispose);
    expect(controller.status, SshConnectionStatus.idle);
    expect(controller.isConnected, isFalse);
  });

  test('connect to a refused port transitions to failed', () async {
    final controller = SshTerminalController();
    addTearDown(controller.dispose);

    // Port 1 is reserved and refuses connections — exercises the real socket
    // + error path without needing a live SSH server.
    await controller.connect(
      const SshConnectionRequest(
        host: '127.0.0.1',
        port: 1,
        username: 'nobody',
        authKind: SshAuthKind.password,
        password: 'x',
      ),
    );

    expect(controller.status, SshConnectionStatus.failed);
    expect(controller.errorMessage, isNotNull);
  }, timeout: const Timeout(Duration(seconds: 20)));
}
