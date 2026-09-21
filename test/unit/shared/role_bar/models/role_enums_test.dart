import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';

void main() {
  group('Role', () {
    group('selectableRoles', () {
      const finishLineRoles = [Role.bibRecorderV2, Role.verifier, Role.fixer];

      test('hides the finish-line roles when they are switched off', () {
        final roles = Role.selectableRoles(includeFinishLineRoles: false);

        expect(roles, isNot(anyOf(finishLineRoles.map(contains).toList())));
      });

      test('keeps every original role when finish-line roles are off', () {
        final roles = Role.selectableRoles(includeFinishLineRoles: false);

        expect(roles, [
          Role.timer,
          Role.bibRecorder,
          Role.coach,
          Role.spectator,
        ]);
      });

      test('offers every role when finish-line roles are switched on', () {
        final roles = Role.selectableRoles(includeFinishLineRoles: true);

        expect(roles, Role.values);
      });
    });
  });
}
