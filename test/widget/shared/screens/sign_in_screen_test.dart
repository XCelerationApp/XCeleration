import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gotrue/gotrue.dart' as gotrue;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:xceleration/core/services/connectivity_service.dart';
import 'package:xceleration/core/services/i_auth_service.dart';
import 'package:xceleration/core/services/i_sync_service.dart';
import 'package:xceleration/shared/screens/sign_in_screen.dart';

@GenerateMocks([IAuthService, ISyncService])
import 'sign_in_screen_test.mocks.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _FakeConnectivityService extends ConnectivityService {
  _FakeConnectivityService({required this.online});
  final bool online;
  @override
  Future<bool> isOnline() async => online;
}

final _online = _FakeConnectivityService(online: true);
final _offline = _FakeConnectivityService(online: false);

/// Pumps through async work without calling pumpAndSettle.
/// pumpAndSettle hangs forever because _floatController.repeat() is an
/// infinite animation inside SignInScreen.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(); // process gesture / microtask queue
  await tester.pump(Duration.zero); // drain resolved futures
  await tester.pump(Duration.zero); // process setState calls
  await tester.pump(Duration.zero); // render dialog / new frame
}

Widget _wrap(Widget child, {required MockISyncService syncService}) {
  return Provider<ISyncService>.value(
    value: syncService,
    child: MaterialApp(home: child),
  );
}

MockISyncService _stubSyncService() {
  final mock = MockISyncService();
  when(mock.syncAll()).thenAnswer((_) => Future.value());
  return mock;
}

MockIAuthService _stubAuthService() {
  final mock = MockIAuthService();
  // Default: sign-in returns null session (no navigation), all others succeed.
  when(mock.signInWithEmailPassword(any, any))
      .thenAnswer((_) async => gotrue.AuthResponse());
  when(mock.signUpWithEmailPassword(any, any))
      .thenAnswer((_) async => gotrue.AuthResponse());
  when(mock.sendPasswordResetEmail(any)).thenAnswer((_) => Future.value());
  return mock;
}

/// Enters valid credentials and taps the primary submit button.
Future<void> _fillAndSubmit(
  WidgetTester tester, {
  String email = 'test@test.com',
  String password = 'password123',
  bool isLogin = true,
}) async {
  await tester.enterText(find.byType(TextFormField).first, email);
  await tester.enterText(find.byType(TextFormField).last, password);
  await tester.tap(find.byType(ElevatedButton));
  await _settle(tester);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockIAuthService mockAuth;
  late MockISyncService mockSync;

  setUp(() {
    mockAuth = _stubAuthService();
    mockSync = _stubSyncService();
  });

  // -------------------------------------------------------------------------
  // Initial UI state
  // -------------------------------------------------------------------------

  group('initial UI state', () {
    testWidgets('shows Sign in title by default', (tester) async {
      await tester.pumpWidget(_wrap(
        SignInScreen(authService: mockAuth, connectivityService: _online),
        syncService: mockSync,
      ));
      await tester.pump();

      expect(find.text('Sign in'), findsWidgets);
    });

    testWidgets('shows email and password TextFormFields', (tester) async {
      await tester.pumpWidget(_wrap(
        SignInScreen(authService: mockAuth, connectivityService: _online),
        syncService: mockSync,
      ));
      await tester.pump();

      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('shows Forgot password button in sign-in mode', (tester) async {
      await tester.pumpWidget(_wrap(
        SignInScreen(authService: mockAuth, connectivityService: _online),
        syncService: mockSync,
      ));
      await tester.pump();

      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('shows submit ElevatedButton', (tester) async {
      await tester.pumpWidget(_wrap(
        SignInScreen(authService: mockAuth, connectivityService: _online),
        syncService: mockSync,
      ));
      await tester.pump();

      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Mode toggle
  // -------------------------------------------------------------------------

  group('mode toggle', () {
    testWidgets('tapping toggle switches to Create account mode',
        (tester) async {
      await tester.pumpWidget(_wrap(
        SignInScreen(authService: mockAuth, connectivityService: _online),
        syncService: mockSync,
      ));
      await tester.pump();

      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pump();

      expect(find.text('Create account'), findsWidgets);
      expect(find.text('Forgot password?'), findsNothing);
    });

    testWidgets('tapping toggle back returns to Sign in mode', (tester) async {
      await tester.pumpWidget(_wrap(
        SignInScreen(authService: mockAuth, connectivityService: _online),
        syncService: mockSync,
      ));
      await tester.pump();

      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pump();
      await tester.tap(find.text('Have an account? Sign in'));
      await tester.pump();

      expect(find.text('Sign in'), findsWidgets);
      expect(find.text('Forgot password?'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Form validation
  // -------------------------------------------------------------------------

  group('form validation', () {
    testWidgets('shows error when email is empty on submit', (tester) async {
      await tester.pumpWidget(_wrap(
        SignInScreen(authService: mockAuth, connectivityService: _online),
        syncService: mockSync,
      ));
      await tester.pump();

      // Only fill password, leave email empty
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
      verifyNever(mockAuth.signInWithEmailPassword(any, any));
    });

    testWidgets('shows error when password is shorter than 6 characters',
        (tester) async {
      await tester.pumpWidget(_wrap(
        SignInScreen(authService: mockAuth, connectivityService: _online),
        syncService: mockSync,
      ));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, 'test@test.com');
      await tester.enterText(find.byType(TextFormField).last, 'abc');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // The hint is always shown below the field; the validator also
      // returns the same string, so we expect at least 2 instances after
      // an invalid submission.
      expect(find.text('Use at least 6 characters'), findsAtLeastNWidgets(2));
      verifyNever(mockAuth.signInWithEmailPassword(any, any));
    });
  });

  // -------------------------------------------------------------------------
  // XCE-189: Connectivity pre-check
  // -------------------------------------------------------------------------

  group('XCE-189 connectivity pre-check', () {
    testWidgets(
        'when offline: shows no-internet dialog and does not call auth service',
        (tester) async {
      await tester.pumpWidget(_wrap(
        SignInScreen(
            authService: mockAuth, connectivityService: _offline),
        syncService: mockSync,
      ));
      await tester.pump();

      await _fillAndSubmit(tester);

      expect(find.text('No internet connection'), findsOneWidget);
      expect(
        find.text('Please check your connection and try again.'),
        findsOneWidget,
      );
      verifyNever(mockAuth.signInWithEmailPassword(any, any));
    });

    testWidgets('when online: calls auth service with entered credentials',
        (tester) async {
      await tester.pumpWidget(_wrap(
        SignInScreen(
            authService: mockAuth, connectivityService: _online),
        syncService: mockSync,
      ));
      await tester.pump();

      await _fillAndSubmit(tester,
          email: 'user@example.com', password: 'secret123');

      verify(mockAuth.signInWithEmailPassword('user@example.com', 'secret123'))
          .called(1);
    });

    testWidgets(
        'when offline in create account mode: shows dialog without calling sign-up',
        (tester) async {
      await tester.pumpWidget(_wrap(
        SignInScreen(
            authService: mockAuth, connectivityService: _offline),
        syncService: mockSync,
      ));
      await tester.pump();

      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pump();

      await _fillAndSubmit(tester, isLogin: false);

      expect(find.text('No internet connection'), findsOneWidget);
      verifyNever(mockAuth.signUpWithEmailPassword(any, any));
    });
  });

  // -------------------------------------------------------------------------
  // XCE-187: Auth error formatting
  // -------------------------------------------------------------------------

  group('XCE-187 auth error formatting', () {
    testWidgets(
        'AuthException with SocketException in message shows friendly error',
        (tester) async {
      when(mockAuth.signInWithEmailPassword(any, any)).thenThrow(
        gotrue.AuthException(
            'ClientException: SocketException: Connection refused'),
      );

      await tester.pumpWidget(_wrap(
        SignInScreen(
            authService: mockAuth, connectivityService: _online),
        syncService: mockSync,
      ));
      await tester.pump();

      await _fillAndSubmit(tester);

      expect(find.text('Error'), findsOneWidget);
      expect(
        find.text(
            'No internet connection. Please check your connection and try again.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'AuthException with ClientException in message shows friendly error',
        (tester) async {
      when(mockAuth.signInWithEmailPassword(any, any)).thenThrow(
        gotrue.AuthException('ClientException: failed to connect'),
      );

      await tester.pumpWidget(_wrap(
        SignInScreen(
            authService: mockAuth, connectivityService: _online),
        syncService: mockSync,
      ));
      await tester.pump();

      await _fillAndSubmit(tester);

      expect(find.text('Error'), findsOneWidget);
      expect(
        find.text(
            'No internet connection. Please check your connection and try again.'),
        findsOneWidget,
      );
    });

    testWidgets('invalid_credentials error shows correct message',
        (tester) async {
      when(mockAuth.signInWithEmailPassword(any, any)).thenThrow(
        gotrue.AuthApiException('Invalid credentials',
            statusCode: '400', code: 'invalid_credentials'),
      );

      await tester.pumpWidget(_wrap(
        SignInScreen(
            authService: mockAuth, connectivityService: _online),
        syncService: mockSync,
      ));
      await tester.pump();

      await _fillAndSubmit(tester);

      expect(find.text('Error'), findsOneWidget);
      expect(
        find.text('Incorrect email or password. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'user_already_exists error shows correct message and switches to sign-in mode',
        (tester) async {
      when(mockAuth.signUpWithEmailPassword(any, any)).thenThrow(
        gotrue.AuthApiException('User already registered',
            statusCode: '422', code: 'user_already_exists'),
      );

      await tester.pumpWidget(_wrap(
        SignInScreen(
            authService: mockAuth, connectivityService: _online),
        syncService: mockSync,
      ));
      await tester.pump();

      // Switch to create account mode
      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pump();

      await _fillAndSubmit(tester, isLogin: false);

      expect(find.text('Error'), findsOneWidget);
      expect(
        find.text(
            'An account with this email already exists. Please sign in instead.'),
        findsOneWidget,
      );

      // Dismiss dialog — mode should have switched back to sign-in
      await tester.tap(find.text('OK'));
      await tester.pump();

      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('AuthWeakPasswordException shows weak password reasons',
        (tester) async {
      when(mockAuth.signUpWithEmailPassword(any, any)).thenThrow(
        gotrue.AuthWeakPasswordException(
          message: 'Weak password',
          statusCode: '422',
          reasons: ['too short', 'no uppercase'],
        ),
      );

      await tester.pumpWidget(_wrap(
        SignInScreen(
            authService: mockAuth, connectivityService: _online),
        syncService: mockSync,
      ));
      await tester.pump();

      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pump();

      await _fillAndSubmit(tester, isLogin: false);

      expect(find.text('Error'), findsOneWidget);
      expect(
        find.text('Password too weak: too short, no uppercase'),
        findsOneWidget,
      );
    });

    testWidgets('unknown error shows generic fallback message', (tester) async {
      when(mockAuth.signInWithEmailPassword(any, any))
          .thenThrow(Exception('Unexpected failure'));

      await tester.pumpWidget(_wrap(
        SignInScreen(
            authService: mockAuth, connectivityService: _online),
        syncService: mockSync,
      ));
      await tester.pump();

      await _fillAndSubmit(tester);

      expect(find.text('Error'), findsOneWidget);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
    });
  });

  // -------------------------------------------------------------------------
  // Forgot password
  // -------------------------------------------------------------------------

  group('forgot password', () {
    testWidgets('tapping with empty email shows info dialog', (tester) async {
      await tester.pumpWidget(_wrap(
        SignInScreen(authService: mockAuth, connectivityService: _online),
        syncService: mockSync,
      ));
      await tester.pump();

      await tester.tap(find.text('Forgot password?'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Info'), findsOneWidget);
      expect(find.text('Enter email to reset password'), findsOneWidget);
      verifyNever(mockAuth.sendPasswordResetEmail(any));
    });

    testWidgets('tapping with filled email calls sendPasswordResetEmail',
        (tester) async {
      await tester.pumpWidget(_wrap(
        SignInScreen(authService: mockAuth, connectivityService: _online),
        syncService: mockSync,
      ));
      await tester.pump();

      await tester.enterText(
          find.byType(TextFormField).first, 'reset@test.com');
      await tester.tap(find.text('Forgot password?'));
      await _settle(tester);

      verify(mockAuth.sendPasswordResetEmail('reset@test.com')).called(1);
      expect(find.text('Password reset email sent'), findsOneWidget);
    });
  });
}
