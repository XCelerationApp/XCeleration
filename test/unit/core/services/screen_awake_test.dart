import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/services/screen_awake.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('xceleration/screen_awake');
  final calls = <Object?>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'setAwake');
      calls.add(call.arguments);
      return null;
    });
  });

  tearDown(() async {
    await ScreenAwake.set(false);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('asks the phone to keep the screen on, then lets it lock again',
      () async {
    await ScreenAwake.set(true);
    expect(ScreenAwake.isOn, isTrue);
    await ScreenAwake.set(false);

    expect(calls, [true, false]);
    expect(ScreenAwake.isOn, isFalse);
  });

  test('asks only when the answer changes', () async {
    await ScreenAwake.set(true);
    await ScreenAwake.set(true);

    expect(calls, [true]);
  });

  test('carries on when the phone has no way to keep it on', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);

    await ScreenAwake.set(true);

    expect(ScreenAwake.isOn, isTrue);
  });
}
