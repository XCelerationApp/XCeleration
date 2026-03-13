import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/core/services/connectivity_sync_service.dart';
import 'package:xceleration/core/services/i_auth_service.dart';
import 'package:xceleration/core/services/i_sync_service.dart';

@GenerateMocks([ISyncService, IAuthService, Connectivity])
import 'connectivity_sync_service_test.mocks.dart';

void main() {
  late ConnectivitySyncService service;
  late MockISyncService mockSync;
  late MockIAuthService mockAuth;
  late MockConnectivity mockConnectivity;
  late StreamController<List<ConnectivityResult>> connectivityController;
  late StreamController<void> writeController;

  setUp(() {
    mockSync = MockISyncService();
    mockAuth = MockIAuthService();
    mockConnectivity = MockConnectivity();
    connectivityController = StreamController<List<ConnectivityResult>>.broadcast();
    writeController = StreamController<void>.broadcast();

    when(mockConnectivity.onConnectivityChanged)
        .thenAnswer((_) => connectivityController.stream);
    when(mockSync.syncAll()).thenAnswer((_) async {});
  });

  tearDown(() async {
    service.stop();
    await connectivityController.close();
    await writeController.close();
  });

  void buildService() {
    service = ConnectivitySyncService(
      sync: mockSync,
      auth: mockAuth,
      writeStream: writeController.stream,
      connectivity: mockConnectivity,
    );
  }

  group('ConnectivitySyncService', () {
    group('start — initial sync', () {
      test('calls syncAll immediately when signed in and online', () {
        fakeAsync((async) {
          when(mockAuth.isSignedIn).thenReturn(true);
          when(mockConnectivity.checkConnectivity())
              .thenAnswer((_) async => [ConnectivityResult.wifi]);
          buildService();

          service.start();
          async.flushMicrotasks();

          verify(mockSync.syncAll()).called(1);
        });
      });

      test('does not call syncAll when signed out', () {
        fakeAsync((async) {
          when(mockAuth.isSignedIn).thenReturn(false);
          when(mockConnectivity.checkConnectivity())
              .thenAnswer((_) async => [ConnectivityResult.wifi]);
          buildService();

          service.start();
          async.flushMicrotasks();

          verifyNever(mockSync.syncAll());
        });
      });

      test('does not call syncAll when offline', () {
        fakeAsync((async) {
          when(mockAuth.isSignedIn).thenReturn(true);
          when(mockConnectivity.checkConnectivity())
              .thenAnswer((_) async => [ConnectivityResult.none]);
          buildService();

          service.start();
          async.flushMicrotasks();

          verifyNever(mockSync.syncAll());
        });
      });

      test('does not throw when connectivity check throws', () {
        fakeAsync((async) {
          when(mockAuth.isSignedIn).thenReturn(true);
          when(mockConnectivity.checkConnectivity())
              .thenThrow(Exception('platform error'));
          buildService();

          expect(() {
            service.start();
            async.flushMicrotasks();
          }, returnsNormally);

          verifyNever(mockSync.syncAll());
        });
      });

      test('calling start twice does not add duplicate connectivity subscription', () {
        fakeAsync((async) {
          when(mockAuth.isSignedIn).thenReturn(true);
          when(mockConnectivity.checkConnectivity())
              .thenAnswer((_) async => [ConnectivityResult.wifi]);
          buildService();

          service.start();
          async.flushMicrotasks();
          service.start(); // second call — subscription must not double up
          async.flushMicrotasks();

          // Only the two initial _syncIfOnWifi calls, not extra from doubled subs
          verify(mockSync.syncAll()).called(2);

          // Fire a connectivity event — should only trigger once
          connectivityController.add([ConnectivityResult.wifi]);
          async.flushMicrotasks();

          verify(mockSync.syncAll()).called(1);
        });
      });
    });

    group('start — connectivity listener', () {
      test('calls syncAll when connectivity changes to wifi and signed in', () {
        fakeAsync((async) {
          when(mockAuth.isSignedIn).thenReturn(false);
          when(mockConnectivity.checkConnectivity())
              .thenAnswer((_) async => [ConnectivityResult.none]);
          buildService();

          service.start();
          async.flushMicrotasks();
          clearInteractions(mockSync);

          when(mockAuth.isSignedIn).thenReturn(true);
          connectivityController.add([ConnectivityResult.wifi]);
          async.flushMicrotasks();

          verify(mockSync.syncAll()).called(1);
        });
      });

      test('does not call syncAll on connectivity event when signed out', () {
        fakeAsync((async) {
          when(mockAuth.isSignedIn).thenReturn(false);
          when(mockConnectivity.checkConnectivity())
              .thenAnswer((_) async => [ConnectivityResult.none]);
          buildService();

          service.start();
          async.flushMicrotasks();

          connectivityController.add([ConnectivityResult.wifi]);
          async.flushMicrotasks();

          verifyNever(mockSync.syncAll());
        });
      });

      test('does not call syncAll on connectivity event when result is not wifi', () {
        fakeAsync((async) {
          when(mockAuth.isSignedIn).thenReturn(true);
          when(mockConnectivity.checkConnectivity())
              .thenAnswer((_) async => [ConnectivityResult.none]);
          buildService();

          service.start();
          async.flushMicrotasks();
          clearInteractions(mockSync);

          connectivityController.add([ConnectivityResult.mobile]);
          async.flushMicrotasks();

          verifyNever(mockSync.syncAll());
        });
      });

      test('does not throw when syncAll throws during connectivity event', () {
        fakeAsync((async) {
          when(mockAuth.isSignedIn).thenReturn(false);
          when(mockConnectivity.checkConnectivity())
              .thenAnswer((_) async => [ConnectivityResult.none]);
          buildService();
          service.start();
          async.flushMicrotasks();

          when(mockAuth.isSignedIn).thenReturn(true);
          when(mockSync.syncAll()).thenThrow(Exception('sync error'));

          expect(() {
            connectivityController.add([ConnectivityResult.wifi]);
            async.flushMicrotasks();
          }, returnsNormally);
        });
      });
    });

    group('start — write stream debounce', () {
      test('calls syncAll after 2-second debounce following a write event', () {
        fakeAsync((async) {
          when(mockAuth.isSignedIn).thenReturn(true);
          when(mockConnectivity.checkConnectivity())
              .thenAnswer((_) async => [ConnectivityResult.wifi]);
          buildService();

          service.start();
          async.flushMicrotasks();
          clearInteractions(mockSync);

          writeController.add(null);
          async.elapse(const Duration(seconds: 1));
          verifyNever(mockSync.syncAll());

          async.elapse(const Duration(seconds: 1));
          async.flushMicrotasks();
          verify(mockSync.syncAll()).called(1);
        });
      });

      test('multiple rapid writes result in a single debounced sync', () {
        fakeAsync((async) {
          when(mockAuth.isSignedIn).thenReturn(true);
          when(mockConnectivity.checkConnectivity())
              .thenAnswer((_) async => [ConnectivityResult.wifi]);
          buildService();

          service.start();
          async.flushMicrotasks();
          clearInteractions(mockSync);

          writeController.add(null);
          async.elapse(const Duration(milliseconds: 500));
          writeController.add(null);
          async.elapse(const Duration(milliseconds: 500));
          writeController.add(null);
          async.elapse(const Duration(milliseconds: 500));
          verifyNever(mockSync.syncAll());

          async.elapse(const Duration(seconds: 2));
          async.flushMicrotasks();
          verify(mockSync.syncAll()).called(1);
        });
      });

      test('does not call syncAll from debounce when signed out', () {
        fakeAsync((async) {
          when(mockAuth.isSignedIn).thenReturn(false);
          when(mockConnectivity.checkConnectivity())
              .thenAnswer((_) async => [ConnectivityResult.none]);
          buildService();

          service.start();
          async.flushMicrotasks();

          writeController.add(null);
          async.elapse(const Duration(seconds: 3));
          async.flushMicrotasks();

          verifyNever(mockSync.syncAll());
        });
      });

      test('does not call syncAll from debounce when offline', () {
        fakeAsync((async) {
          when(mockAuth.isSignedIn).thenReturn(true);
          when(mockConnectivity.checkConnectivity())
              .thenAnswer((_) async => [ConnectivityResult.none]);
          buildService();

          service.start();
          async.flushMicrotasks();

          writeController.add(null);
          async.elapse(const Duration(seconds: 3));
          async.flushMicrotasks();

          verifyNever(mockSync.syncAll());
        });
      });
    });

    group('stop', () {
      test('prevents connectivity events from triggering sync after stop', () {
        fakeAsync((async) {
          when(mockAuth.isSignedIn).thenReturn(true);
          when(mockConnectivity.checkConnectivity())
              .thenAnswer((_) async => [ConnectivityResult.none]);
          buildService();

          service.start();
          async.flushMicrotasks();
          service.stop();

          connectivityController.add([ConnectivityResult.wifi]);
          async.flushMicrotasks();

          verifyNever(mockSync.syncAll());
        });
      });

      test('prevents write stream events from triggering sync after stop', () {
        fakeAsync((async) {
          when(mockAuth.isSignedIn).thenReturn(true);
          when(mockConnectivity.checkConnectivity())
              .thenAnswer((_) async => [ConnectivityResult.wifi]);
          buildService();

          service.start();
          async.flushMicrotasks();
          clearInteractions(mockSync);
          service.stop();

          writeController.add(null);
          async.elapse(const Duration(seconds: 3));
          async.flushMicrotasks();

          verifyNever(mockSync.syncAll());
        });
      });

      test('allows start to re-subscribe after stop', () {
        fakeAsync((async) {
          when(mockAuth.isSignedIn).thenReturn(false);
          when(mockConnectivity.checkConnectivity())
              .thenAnswer((_) async => [ConnectivityResult.none]);
          buildService();

          service.start();
          async.flushMicrotasks();
          service.stop();

          when(mockAuth.isSignedIn).thenReturn(true);
          when(mockConnectivity.checkConnectivity())
              .thenAnswer((_) async => [ConnectivityResult.wifi]);

          service.start();
          async.flushMicrotasks();

          verify(mockSync.syncAll()).called(1);
        });
      });
    });
  });
}
