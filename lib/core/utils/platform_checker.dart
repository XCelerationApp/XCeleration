import 'dart:io';

abstract class PlatformCheckerInterface {
  bool get isAndroid;
  bool get isIOS;
}

class PlatformChecker implements PlatformCheckerInterface {
  const PlatformChecker();

  @override
  bool get isAndroid => Platform.isAndroid;

  @override
  bool get isIOS => Platform.isIOS;
}
