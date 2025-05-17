import 'package:flutter/material.dart';
import '../theme/typography.dart';
import '../theme/app_colors.dart';

/// Custom alert dialog with app theme styling applied
class BasicAlertDialog extends StatelessWidget {
  final String title;
  final String content;
  final List<Widget> actions;
  final double backgroundTint;

  const BasicAlertDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.backgroundTint = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      backgroundColor: AppColors.backgroundColor,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      title: Text(
        title,
        style: AppTypography.titleSemibold.copyWith(
          color: AppColors.primaryColor,
        ),
      ),
      content: Text(
        content,
        style: AppTypography.bodyRegular.copyWith(
          color: AppColors.mediumColor,
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: actions,
    );
  }
}

class DialogUtils {
  
  /// Simple dialog that just shows a message and an ok button
  static Future<void> showMessageDialog(
    BuildContext context, {
    required String title,
    required String message,
    final String doneText = 'OK',
    double barrierTint = .54,
  }) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha((barrierTint * 255).round()),
      builder: (context) => BasicAlertDialog(
        title: title,
        content: message,
        actions: [
          TextButton(
            child: Text(doneText, style: AppTypography.buttonText),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
  

  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = 'Yes',
    String cancelText = 'No',
    Color barrierColor = Colors.black54,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierColor: barrierColor,
          builder: (context) => BasicAlertDialog(
            title: title,
            content: content,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelText, style: AppTypography.buttonText),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmText, style: AppTypography.buttonText),
              ),
            ],
          ),
        ) ??
        false;
  }

  static void showErrorDialog(
    BuildContext context, {
    required String message,
    String? title,
  }) {
    debugPrint(message);
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).viewInsets.top + 30,
        left: MediaQuery.of(context).size.width * 0.05,
        right: MediaQuery.of(context).size.width * 0.05,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.red.shade500,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.2 * 255).round()),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }

  static void showSuccessDialog(
    BuildContext context, {
    required String message,
    String? title,
  }) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).viewInsets.top + 50,
        left: MediaQuery.of(context).size.width * 0.05,
        right: MediaQuery.of(context).size.width * 0.05,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.2 * 255).round()),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }

  /// Shows a loading dialog with a progress indicator and custom message
  /// Returns the AlertDialog instance that was created
  static AlertDialog showLoadingDialog(
    BuildContext context, {
    required String message,
    Color indicatorColor = const Color(0xFFE2572B),
  }) {
    AlertDialog alert = AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
    
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
    
    return alert;
  }
}
