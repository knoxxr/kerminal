import 'package:flutter_test/flutter_test.dart';
import 'package:kerminal/domain/entities/host.dart';

void main() {
  group('displayGroup', () {
    test('falls back to the default group when unset or blank', () {
      expect(displayGroup(null), kDefaultGroup);
      expect(displayGroup(''), kDefaultGroup);
      expect(displayGroup('   '), kDefaultGroup);
    });

    test('folds the legacy Korean default into the current one', () {
      // Hosts saved by the Korean-UI builds carry '기본' in the database. Without
      // this, an existing user would suddenly see two default groups.
      expect(displayGroup(kLegacyDefaultGroup), kDefaultGroup);
    });

    test('keeps user-chosen names, trimmed', () {
      expect(displayGroup('Production'), 'Production');
      expect(displayGroup('  Staging  '), 'Staging');
    });
  });
}
