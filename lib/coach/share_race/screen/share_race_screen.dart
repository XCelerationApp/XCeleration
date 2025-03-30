import 'package:flutter/material.dart';
import '../controller/share_race_controller.dart';
import '../widgets/share_format_selection_widget.dart';

class ShareSheetScreen extends StatefulWidget {
  final ShareRaceController controller;

  const ShareSheetScreen({
    super.key,
    required this.controller,
  });

  @override
  State<ShareSheetScreen> createState() => _ShareSheetScreenState();
}

class _ShareSheetScreenState extends State<ShareSheetScreen> {
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
        // const SizedBox(height: 8),
        // ShareMethodSelectionWidget(
        //   controller: widget.controller,
        // ),
        // const SizedBox(height: 32),
        ShareFormatSelectionWidget(
          controller: widget.controller,
        ),
      ],
    );
  }
}
