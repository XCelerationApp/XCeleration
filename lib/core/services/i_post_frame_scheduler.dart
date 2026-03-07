import 'package:flutter/widgets.dart';

abstract interface class IPostFrameScheduler {
  void schedulePostFrame(VoidCallback callback);
}
