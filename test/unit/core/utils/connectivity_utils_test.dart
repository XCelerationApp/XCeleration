import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/core/utils/connectivity_utils.dart';

@GenerateMocks([Connectivity])
import 'connectivity_utils_test.mocks.dart';

void main() {
  late MockConnectivity mockConnectivity;

  setUp(() {
    mockConnectivity = MockConnectivity();
  });

  group('ConnectivityUtils', () {
    group('isOnline', () {
      test('returns true when results contain wifi', () async {
        when(mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.wifi]);

        final result =
            await ConnectivityUtils.isOnline(connectivity: mockConnectivity);

        expect(result, isTrue);
      });

      test('returns true when results contain mobile', () async {
        when(mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.mobile]);

        final result =
            await ConnectivityUtils.isOnline(connectivity: mockConnectivity);

        expect(result, isTrue);
      });

      test('returns true when results contain multiple connections', () async {
        when(mockConnectivity.checkConnectivity()).thenAnswer(
            (_) async => [ConnectivityResult.wifi, ConnectivityResult.mobile]);

        final result =
            await ConnectivityUtils.isOnline(connectivity: mockConnectivity);

        expect(result, isTrue);
      });

      test('returns false when results contain only none', () async {
        when(mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.none]);

        final result =
            await ConnectivityUtils.isOnline(connectivity: mockConnectivity);

        expect(result, isFalse);
      });

      test('returns false and does not throw when connectivity throws', () async {
        when(mockConnectivity.checkConnectivity())
            .thenThrow(Exception('platform error'));

        final result =
            await ConnectivityUtils.isOnline(connectivity: mockConnectivity);

        expect(result, isFalse);
      });
    });
  });
}
