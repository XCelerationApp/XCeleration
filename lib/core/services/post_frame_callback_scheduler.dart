import 'package:flutter/material.dart';

abstract interface class IPostFrameCallbackScheduler {
  void addPostFrameCallback(VoidCallback callback);
}

class WidgetsBindingAdapter implements IPostFrameCallbackScheduler {
  @override
  void addPostFrameCallback(VoidCallback callback) {
    WidgetsBinding.instance.addPostFrameCallback((_) => callback());
  }
}
