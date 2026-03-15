import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gotrue/gotrue.dart' as gotrue;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:xceleration/core/services/connectivity_service.dart';
import 'package:xceleration/core/services/i_auth_service.dart';
import 'package:xceleration/core/services/i_sync_service.dart';
import 'package:xceleration/core/services/profile_service.dart';
import 'package:xceleration/shared/screens/sign_in_screen.dart';

@GenerateMocks([IAuthService, ISyncService])
import 'sign_in_screen_test.mocks.dart';

class _FakeProfileService extends Fake implements ProfileService {
  @override
  Future<void> ensureProfileUpsert() async {}
}

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
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(Duration.zero);
  await tester.pump(Duration.zero);
  await tester.pump(Duration.zero);
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
  when(mock.signInWithEmailPassword(any, any))
      .thenAnswer((_) async => gotrue.AuthResponse());
  when(mock.signUpWithEmailPassword(any, any))
      .thenAnswer((_) async => gotrue.AuthResponse());
  when(mock.sendPasswordResetEmail(any)).thenAnswer((_) => Future.value());
  return mock;
}

/// Enters valid credentials and taps the submit button.
Future<void> _fillAndSubmit(
  WidgetTester tester, {
  String email = 'test@test.com',
  String password = 'password123',
  bool isLogin = true,
}) async {
  await tester.enterText(find.byType(TextField).first, email);
  await tester.enterText(find.byType(TextField).last, password);
  await tester.tap(find.text(isLogin ? 'Sign In' : 'Create Account'));
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
        SignInScreen(authService: mockAuth, connectivityService: _online, profileService: _FakeProfileService()),
        syncService: mockSync,
      ));
      await tester.pump();

      expect(find.textContaining('Sign in'), findsWidgets);
    });

    testWidgets('shows email and password TextFields', (tester) async {
      await tester.pumpWidget(_wrap(
        SignInScreen(authService: mockAuth, connectivityService: _online, profileService: _FakeProfileService()),
        syncService: mockSync,
      ));
      await tester.pump();

      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('shows Forgot password button in sign-in mode', (tester) async {
      await tester.pumpWidget(_wrap(
        SignInScreen(authService: mockAuth, connectivityService: _online, profileService: _FakeProfileService()),
        syncService: mockSync,
      ));
      await tester.pump();

      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('shows submit button', (tester) async {
      await tester.pumpWidget(_wrap(
        SignInScreen(authService: mockAuth, connectivityService: _online, profileService: _FakeProfileService()),
        syncService: mockSync,
      ));
      await tester.pump();

      expect(find.text('Sign In'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Mode toggle
  // -------------------------------------------------------------------------

  group('mode toggle', () {
    testWidgets('tapping toggle switches to Create account mode',
        (tester) async {
      await tester.pumpWidget(_wrap(
        SignInScreen(authService: mockAuth, connectivityService: _online, profileService: _FakeProfileService()),
        syncService: mockSync,
      ));
      await tester.pump();

      await tester.tap(find.text('Create one'));
      await tester.pump();

      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Forgot password?'), findsNothing);
    });

    testWidgets('tapping toggle back returns to Sign in mode', (tester) async {
      await tester.pumpWidget(_wrap(
        SignInScreen(authService: mockAuth, connectivityService: _online, profileService: _FakeProfileService()),
        syncService: mockSync,
      ));
      await tester.pump();

      await tester.tap(find.text('Create one'));
      await tester.pump();
      await tester.tap(find.text('Sign in'));
      await tester.pump();

      expect(find.textContaining('Sign in'), findsWidgets);
      expect(find.text('Forgot password?'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Form validation
  // -------------------------------------------------------------------------

  group('form validation', () {
    testWidgets('shows error when email is empty on submit', (tester) async {
      await tester.pumpWidget(_wrap(
        SignInScreen(authService: mockAuth, connectivityService: _online, profileService: _FakeProfileService()),
        syncService: mockSync,
      ));
      await tester.pump();

      // Only fill password, leave email empty
      await tester.enterText(find.byType(TextField).last, 'password123');
      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
      verifyNever(mockAuth.signInWithEmailPassword(any, any));
    });

    testWidgets('shows error when password is shorter than 6 characters',
        (tester) async {
      await tester.pumpWidget(_wrap(
        SignInScreen(authService: mockAuth, connectivityService: _online, profileService: _FakeProfileService()),
        syncService: mockSync,
      ));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'test@test.com');
      await tester.enterText(find.byType(TextField).last, 'abc');
      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(find.text('Use at least 6 characters'), findsOneWidget);
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
            authService: mockAuth, connectivityService: _offline, profileService: _FakeProfileService()),
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
            authService: mockAuth, connectivityService: _online, profileService: _FakeProfileService()),
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
            authService: mockAuth, connectivityService: _offline, profileService: _FakeProfileService()),
        syncService: mockSync,
      ));
      await tester.pump();

      await tester.tap(find.text('Create one'));
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
            authService: mockAuth, connectivityService: _online, profileService: _FakeProfileService()),
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
            authService: mockAuth, connectivityService: _online, profileService: _FakeProfileService()),
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
            authService: mockAuth, connectivityService: _online, profileService: _FakeProfileService()),
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
            authService: mockAuth, connectivityService: _online, profileService: _FakeProfileService()),
        syncService: mockSync,
      ));
      await tester.pump();

      // Switch to create account mode
      await tester.tap(find.text('Create one'));
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
            authService: mockAuth, connectivityService: _online, profileService: _FakeProfileService()),
        syncService: mockSync,
      ));
      await tester.pump();

      await tester.tap(find.text('Create one'));
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
            authService: mockAuth, connectivityService: _online, profileService: _FakeProfileService()),
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
        SignInScreen(authService: mockAuth, connectivityService: _online, profileService: _FakeProfileService()),
        syncService: mockSync,
      ));
      await tester.pump();

      await tester.tap(find.text('Forgot password?'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Email required'), findsOneWidget);
      expect(find.text('Enter your email address above, then tap Forgot Password.'), findsOneWidget);
      verifyNever(mockAuth.sendPasswordResetEmail(any));
    });

    testWidgets('tapping with filled email calls sendPasswordResetEmail',
        (tester) async {
      await tester.pumpWidget(_wrap(
        SignInScreen(authService: mockAuth, connectivityService: _online, profileService: _FakeProfileService()),
        syncService: mockSync,
      ));
      await tester.pump();

      await tester.enterText(
          find.byType(TextField).first, 'reset@test.com');
      await tester.tap(find.text('Forgot password?'));
      await _settle(tester);

      verify(mockAuth.sendPasswordResetEmail('reset@test.com')).called(1);
      expect(find.text('Reset email sent'), findsOneWidget);
    });
  });
}
