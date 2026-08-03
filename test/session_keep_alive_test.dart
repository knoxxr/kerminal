import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerminal/data/platform/session_keep_alive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('kerminal/session_keep_alive');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('starts with the session count and stops when the last tab closes',
      () async {
    // Known baseline: the advertised count is static and survives between tests.
    await SessionKeepAlive.reset();
    calls.clear();

    await SessionKeepAlive.sync(1);
    await SessionKeepAlive.sync(2);
    // Unchanged count must not re-post the notification.
    await SessionKeepAlive.sync(2);
    await SessionKeepAlive.sync(0);

    expect(calls.map((c) => c.method).toList(), ['start', 'start', 'stop']);
    expect(calls[0].arguments, {'sessions': 1});
    expect(calls[1].arguments, {'sessions': 2});
  });

  test('reset always stops, even with nothing advertised', () async {
    await SessionKeepAlive.reset();
    expect(calls.single.method, 'stop');
  });
}
