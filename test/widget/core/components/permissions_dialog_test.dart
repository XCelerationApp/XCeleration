import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:xceleration/core/components/permissions_components.dart';
import 'package:xceleration/core/services/permissions_service.dart';

import 'permissions_dialog_test.mocks.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

@GenerateMocks([PermissionsService])
void main() {
  group('PermissionStatusData', () {
    group('from', () {
      test('granted status produces Granted label', () {
        final data = PermissionStatusData.from(PermissionStatus.granted);
        expect(data.label, 'Granted');
        expect(data.actionLabel, 'Granted');
      });

      test('permanently denied status produces Settings action label', () {
        final data =
            PermissionStatusData.from(PermissionStatus.permanentlyDenied);
        expect(data.label, 'Permanently Denied');
        expect(data.actionLabel, 'Settings');
      });

      test('denied status produces Request action label', () {
        final data = PermissionStatusData.from(PermissionStatus.denied);
        expect(data.label, 'Denied');
        expect(data.actionLabel, 'Request');
      });

      test('restricted status produces Restricted label', () {
        final data = PermissionStatusData.from(PermissionStatus.restricted);
        expect(data.label, 'Restricted');
        expect(data.actionLabel, 'Request');
      });
    });
  });

  group('PermissionsDialog', () {
    late MockPermissionsService mockService;

    setUp(() {
      mockService = MockPermissionsService();
    });

    testWidgets('shows loading indicator while permissions are loading',
        (tester) async {
      final completer = Completer<Map<Permission, PermissionStatus>>();
      when(mockService.checkAllPermissions())
          .thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        _wrap(PermissionsDialog(permissionsService: mockService)),
      );
      // Pump once to trigger initState without resolving the future
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future so no pending async work remains
      completer.complete({});
      await tester.pumpAndSettle();
    });

    testWidgets('shows "No permissions to display" when list is empty',
        (tester) async {
      when(mockService.checkAllPermissions())
          .thenAnswer((_) async => <Permission, PermissionStatus>{});

      await tester.pumpWidget(
        _wrap(PermissionsDialog(permissionsService: mockService)),
      );
      await tester.pumpAndSettle();

      expect(find.text('No permissions to display'), findsOneWidget);
    });

    testWidgets('shows permission name tiles after loading completes',
        (tester) async {
      when(mockService.checkAllPermissions()).thenAnswer(
        (_) async => <Permission, PermissionStatus>{
          Permission.camera: PermissionStatus.granted,
          Permission.location: PermissionStatus.denied,
        },
      );
      when(mockService.getPermissionName(Permission.camera))
          .thenReturn('Camera');
      when(mockService.getPermissionName(Permission.location))
          .thenReturn('Location');

      await tester.pumpWidget(
        _wrap(PermissionsDialog(permissionsService: mockService)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
    });

    testWidgets('shows correct status labels for each permission',
        (tester) async {
      when(mockService.checkAllPermissions()).thenAnswer(
        (_) async => <Permission, PermissionStatus>{
          Permission.camera: PermissionStatus.granted,
          Permission.location: PermissionStatus.denied,
        },
      );
      when(mockService.getPermissionName(Permission.camera))
          .thenReturn('Camera');
      when(mockService.getPermissionName(Permission.location))
          .thenReturn('Location');

      await tester.pumpWidget(
        _wrap(PermissionsDialog(permissionsService: mockService)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Granted'), findsOneWidget);
      expect(find.text('Denied'), findsOneWidget);
    });

    testWidgets('shows "App Permissions" title', (tester) async {
      when(mockService.checkAllPermissions())
          .thenAnswer((_) async => <Permission, PermissionStatus>{});

      await tester.pumpWidget(
        _wrap(PermissionsDialog(permissionsService: mockService)),
      );
      await tester.pumpAndSettle();

      expect(find.text('App Permissions'), findsOneWidget);
    });

    testWidgets('shows Close button', (tester) async {
      when(mockService.checkAllPermissions())
          .thenAnswer((_) async => <Permission, PermissionStatus>{});

      await tester.pumpWidget(
        _wrap(PermissionsDialog(permissionsService: mockService)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('tapping refresh icon reloads permissions', (tester) async {
      when(mockService.checkAllPermissions())
          .thenAnswer((_) async => <Permission, PermissionStatus>{});

      await tester.pumpWidget(
        _wrap(PermissionsDialog(permissionsService: mockService)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      // checkAllPermissions called once on init, once on refresh
      verify(mockService.checkAllPermissions()).called(2);
    });
  });
}
