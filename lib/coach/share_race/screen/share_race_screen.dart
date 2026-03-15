import 'package:flutter/material.dart';
import '../controller/share_race_controller.dart';
import '../widgets/share_format_selection_widget.dart';

class ShareRaceScreen extends StatefulWidget {
  final ShareRaceController controller;

  const ShareRaceScreen({
    super.key,
    required this.controller,
  });

  @override
  State<ShareRaceScreen> createState() => _ShareRaceScreenState();
}

class _ShareRaceScreenState extends State<ShareRaceScreen> {
  @override
  void initState() {
    super.initState();
    // Add listener to the controller
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    // Remove listener when widget is disposed
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  // This will trigger a rebuild when the controller notifies
  void _onControllerChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ShareFormatSelectionWidget(
          controller: widget.controller,
        ),
      ],
    );
  }
}
