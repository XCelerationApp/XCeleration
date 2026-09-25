import 'package:flutter/material.dart';

void scrollToBottom(ScrollController scrollController) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  });
}

