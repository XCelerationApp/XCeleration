import 'package:flutter/material.dart';

abstract interface class ITextInputFactory {
  TextEditingController createController(String text);
  FocusNode createFocusNode();
}
