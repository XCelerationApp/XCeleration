import 'package:flutter/material.dart';
import '../controller/share_race_controller.dart';
import '../widgets/share_format_selection_widget.dart';

class ShareRaceScreen extends StatelessWidget {
  final ShareRaceController controller;

  const ShareRaceScreen({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    // ShareRaceController never calls notifyListeners() — no listener needed.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ShareFormatSelectionWidget(
          controller: controller,
        ),
      ],
    );
  }
}
