import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kerminal/data/remote/feedback_service.dart';

void main() {
  test('currentPlatformLabel returns a non-empty lowercase label', () {
    final label = currentPlatformLabel();
    expect(label, isNotEmpty);
    expect(label, label.toLowerCase());
  });

  test('FeedbackException surfaces its message', () {
    const e = FeedbackException('nope');
    expect(e.message, 'nope');
    expect('$e', 'nope');
  });

  // The destination address lives only in the Edge Function's FEEDBACK_TO
  // secret. A `mailto:` link or a bundled constant would hand it to anyone who
  // installs the app or reads this (public) repository, so guard against
  // someone "simplifying" the flow later.
  test('no email address or mailto: link is embedded in the app', () {
    final offenders = <String>[];
    final email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+');
    final mailto = RegExp(r'mailto:', caseSensitive: false);

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Doc comments legitimately mention addresses (e.g. example.com).
        if (line.trimLeft().startsWith('//')) continue;
        if (email.hasMatch(line) || mailto.hasMatch(line)) {
          offenders.add('${entity.path}:${i + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Contact addresses must stay server-side:\n'
          '${offenders.join('\n')}',
    );
  });
}
