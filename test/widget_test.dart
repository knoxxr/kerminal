import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerminal/domain/entities/host.dart';

void main() {
  test('Host.copyWith overrides only the given fields', () {
    const host = Host(
      id: '1',
      label: 'web',
      hostname: 'example.com',
      port: 22,
      username: 'root',
      authMethod: AuthMethod.password,
    );

    final updated = host.copyWith(port: 2222);

    expect(updated.port, 2222);
    expect(updated.hostname, 'example.com');
    expect(updated.id, '1');
  });

  testWidgets('Empty-state smoke test renders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('No hosts yet.'))),
    );
    expect(find.text('No hosts yet.'), findsOneWidget);
  });
}
