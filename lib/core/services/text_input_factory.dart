import 'package:flutter/material.dart';

import 'i_text_input_factory.dart';

class TextInputFactory implements ITextInputFactory {
  const TextInputFactory();

  @override
  TextEditingController createController(String text) {
    return TextEditingController(text: text);
  }

  @override
  FocusNode createFocusNode() {
    return FocusNode();
  }
}
