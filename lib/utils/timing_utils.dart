import 'package:flutter/material.dart';

void scrollToBottom(ScrollController scrollController) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  });
}

Duration getCurrentDuration(DateTime? startTime, Duration? endTime) {
  if (startTime == null) {
    return endTime ?? Duration.zero;
  }
  return DateTime.now().difference(startTime);
}
