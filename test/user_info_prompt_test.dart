import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerminal/core/router/app_router.dart';
import 'package:kerminal/data/ssh/ssh_service.dart';
import 'package:kerminal/presentation/terminal/user_info_prompt.dart';

void main() {
  test('a round with no prompts is answered without any UI', () async {
    // Servers use an empty round to show a banner. Waiting for a dialog here
    // would stall authentication, so it must answer on its own.
    final respond = buildUserInfoResponder();
    expect(await respond('', 'Welcome', const []), isEmpty);
  });

  test('returns null when there is no navigator to ask with', () async {
    // Better to abandon this auth method than to hang the connection forever.
    final respond = buildUserInfoResponder();
    final answers = await respond('2FA', 'Code?', const [
      SshPrompt(text: 'Verification code: ', echo: true),
    ]);
    expect(answers, isNull);
  });

  testWidgets('asks one field per prompt and returns the answers in order',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: const Scaffold(body: SizedBox()),
      ),
    );

    final respond = buildUserInfoResponder();
    final pending = respond('Two-factor', 'Enter your codes', const [
      SshPrompt(text: 'Password: ', echo: false),
      SshPrompt(text: 'Code: ', echo: true),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Two-factor'), findsOneWidget);
    expect(find.text('Enter your codes'), findsOneWidget);
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));

    await tester.enterText(fields.at(0), 'hunter2');
    await tester.enterText(fields.at(1), '123456');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(await pending, ['hunter2', '123456']);
  });

  testWidgets('cancelling abandons the method rather than sending blanks',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: const Scaffold(body: SizedBox()),
      ),
    );

    final respond = buildUserInfoResponder();
    final pending = respond('2FA', '', const [
      SshPrompt(text: 'Code: ', echo: true),
    ]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Empty answers would be sent to the server as a wrong code; null tells
    // dartssh2 to give up on keyboard-interactive instead.
    expect(await pending, isNull);
  });

  testWidgets('a secret prompt is obscured, a code prompt is not',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: const Scaffold(body: SizedBox()),
      ),
    );

    final respond = buildUserInfoResponder();
    final pending = respond('', '', const [
      SshPrompt(text: 'Password: ', echo: false),
      SshPrompt(text: 'Code: ', echo: true),
    ]);
    await tester.pumpAndSettle();

    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields[0].obscureText, isTrue, reason: 'echo: false is a secret');
    expect(fields[1].obscureText, isFalse, reason: 'echo: true may be shown');

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await pending;
  });
}
