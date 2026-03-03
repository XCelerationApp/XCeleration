import 'dart:async';
import 'package:xceleration/core/utils/logger.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Logger.silent = true;
  await testMain();
}
