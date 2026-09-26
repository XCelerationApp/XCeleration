import 'package:flutter/material.dart';
import '../../../../../../core/components/button_components.dart';
import '../../../../../../core/components/dialog_utils.dart';

/// Loads the results from the volunteers' phones again. Secondary to Next,
/// and asks first: it throws away every fix made since they were loaded.
class ReloadButton extends StatelessWidget {
  /// Function to call when the reload button is pressed
  final VoidCallback onPressed;

  const ReloadButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SecondaryButton(
      text: 'Load Again',
      icon: Icons.refresh,
      size: ButtonSize.fullWidth,
      onPressed: () async {
        final again = await DialogUtils.showConfirmationDialog(
          context,
          title: 'Load the Results Again?',
          content: 'This connects to the volunteers\' phones again. Any '
              'bibs or times you fixed here are lost.',
          confirmText: 'Load Again',
          cancelText: 'Cancel',
        );
        if (again) onPressed();
      },
    );
  }
}
