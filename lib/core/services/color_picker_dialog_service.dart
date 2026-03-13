import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

abstract interface class IColorPickerDialogService {
  void showColorPicker(
    BuildContext context, {
    required Color currentColor,
    required ValueChanged<Color> onColorChanged,
  });
}

class ColorPickerDialogService implements IColorPickerDialogService {
  @override
  void showColorPicker(
    BuildContext context, {
    required Color currentColor,
    required ValueChanged<Color> onColorChanged,
  }) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: currentColor,
              onColorChanged: onColorChanged,
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Done'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}
