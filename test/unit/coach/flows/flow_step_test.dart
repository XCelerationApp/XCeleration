import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/flows/model/flow_model.dart';

FlowStep _step() => FlowStep(
      title: 'Step',
      description: 'Description',
      content: const SizedBox(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlowStep', () {
    group('notifyContentChanged', () {
      test('emits an event on onContentChange', () async {
        final step = _step();
        bool emitted = false;
        step.onContentChange.listen((_) => emitted = true);
        step.notifyContentChanged();
        await Future<void>.delayed(Duration.zero);
        expect(emitted, isTrue);
        step.dispose();
      });
    });

    group('onContentChange', () {
      test('supports multiple listeners (broadcast stream)', () async {
        final step = _step();
        int count = 0;
        step.onContentChange.listen((_) => count++);
        step.onContentChange.listen((_) => count++);
        step.notifyContentChanged();
        await Future<void>.delayed(Duration.zero);
        expect(count, 2);
        step.dispose();
      });
    });

    group('dispose', () {
      test('closes the stream so notifyContentChanged throws StateError', () {
        final step = _step();
        step.dispose();
        expect(step.notifyContentChanged, throwsStateError);
      });
    });
  });
}
