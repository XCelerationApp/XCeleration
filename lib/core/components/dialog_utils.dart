import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import '../theme/typography.dart';
import '../theme/app_colors.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:async';

/// Exception thrown when an operation is canceled
class OperationCanceledException implements Exception {
  final String message;

  OperationCanceledException([this.message = 'Operation was canceled']);

  @override
  String toString() => message;
}

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
    Logger.d(message);
    showOverlayNotification(
      context,
      message: message,
      icon: Icons.error_outline,
      backgroundColor: AppColors.lightColor,
      textColor: Colors.red.shade500,
      iconColor: Colors.red.shade500,
      duration: const Duration(seconds: 3),
    );
  }

  static void showSuccessDialog(
    BuildContext context, {
    required String message,
    String? title,
  }) {
    showOverlayNotification(
      context,
      message: message,
      icon: Icons.check_circle_outline,
      backgroundColor: AppColors.lightColor,
      textColor: Colors.green.shade700,
      iconColor: Colors.green.shade700,
      duration: const Duration(seconds: 3),
    );
  }

  /// Executes an async function while showing a loading dialog
  /// Returns the result of the operation or null if canceled
  /// The operation is automatically canceled if the dialog is dismissed
  static Future<T?> executeWithLoadingDialog<T>(
    BuildContext context, {
    required Future<T> Function() operation,
    required String loadingMessage,
    bool allowCancel = true,
    String cancelButtonText = 'Cancel',
    Color indicatorColor = AppColors.primaryColor,
  }) async {
    // Use a Completer to create a future we can complete manually
    final Completer<T?> completer = Completer<T?>();

    // Track whether the operation has been completed or canceled
    bool isCompleted = false;

    // This value is returned to the caller when the dialog is dismissed
    T? result;

    // Create a key to ensure we can always find and dismiss the dialog
    final GlobalKey<State> dialogKey = GlobalKey<State>();

    // Show the loading dialog
    LoadingDialog.show(
      context,
      key: dialogKey,
      message: loadingMessage,
      indicatorColor: indicatorColor,
      showCancelButton: allowCancel,
      cancelButtonText: cancelButtonText,
      onCancel: () {
        if (!isCompleted) {
          isCompleted = true;
          completer.completeError(OperationCanceledException());
        }
      },
    );

    // Execute the operation in a separate isolate or thread
    // and handle completion/errors
    runZonedGuarded(
      () async {
        try {
          // Start the operation
          final operationResult = await operation();

          // Check if operation was already canceled or completed
          if (!isCompleted) {
            isCompleted = true;
            result = operationResult;
            completer.complete(operationResult);
          }
        } catch (e) {
          // Only propagate error if not already completed
          if (!isCompleted) {
            isCompleted = true;
            completer.completeError(e);
          }
        }
      },
      (error, stack) {
        // Handle any unexpected errors in the operation
        if (!isCompleted) {
          isCompleted = true;
          completer.completeError(error);
        }
      },
    );

    try {
      // Wait for the operation to complete or be canceled
      result = await completer.future;

      // Dismiss the dialog safely if it hasn't been dismissed already
      if (dialogKey.currentContext != null) {
        Navigator.of(dialogKey.currentContext!, rootNavigator: true).pop();
      } else if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      return result;
    } catch (e) {
      // Dismiss dialog on error if it hasn't been dismissed already
      if (dialogKey.currentContext != null) {
        Navigator.of(dialogKey.currentContext!, rootNavigator: true).pop();
      } else if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Return null if it was a cancellation, otherwise rethrow
      if (e is OperationCanceledException) {
        return null;
      }
      rethrow;
    }
  }

  /// Shows a toast notification that appears above all other UI elements
  /// and automatically dismisses after a set duration
  ///
  /// This is useful for showing feedback messages without blocking the UI
  /// and is visible even when dialogs are present
  static void showOverlayNotification(
    BuildContext context, {
    required String message,
    IconData? icon,
    Color backgroundColor = AppColors.lightColor,
    Color textColor = AppColors.darkColor,
    Color iconColor = AppColors.darkColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    // Log the message for debugging
    Logger.d(message);

    // Create FToast instance
    final FToast fToast = FToast();

    // Initialize fToast with context
    fToast.init(context);

    // Create custom toast widget
    Widget toastWidget = Material(
      elevation: 3.0,
      borderRadius: BorderRadius.circular(8),
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                message,
                style: AppTypography.bodyRegular.copyWith(
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Show the custom toast at the top of the screen
    fToast.showToast(
      child: toastWidget,
      gravity: ToastGravity.TOP,
      toastDuration: duration,
      fadeDuration: const Duration(milliseconds: 150),
    );
  }
}

/// A customizable loading dialog with a title, loading indicator, message, and optional cancel button
class LoadingDialog extends StatelessWidget {
  final GlobalKey? dialogKey;

  /// The title to display at the top of the dialog
  final String title;

  /// The loading message to display below the indicator
  final String message;

  /// The color of the loading indicator
  final Color indicatorColor;

  /// Whether to show a cancel button
  final bool showCancelButton;

  /// The text to display on the cancel button
  final String cancelButtonText;

  /// Callback when the cancel button is pressed
  final VoidCallback? onCancel;

  /// Create a loading dialog with a title, message, and optional cancel button
  const LoadingDialog({
    super.key,
    this.dialogKey,
    this.title = 'Please Wait',
    required this.message,
    this.indicatorColor = AppColors.primaryColor,
    this.showCancelButton = false,
    this.cancelButtonText = 'Cancel',
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: dialogKey,
      title: Text(
        title,
        style: AppTypography.titleSemibold.copyWith(
          color: indicatorColor,
        ),
        textAlign: TextAlign.center,
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      backgroundColor: AppColors.lightColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(width: 20),
          Flexible(
            child: Text(
              message,
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.darkColor,
              ),
              textAlign: TextAlign.center,
              softWrap: true,
            ),
          ),
        ],
      ),
      actions: showCancelButton
          ? [
              TextButton(
                onPressed: () {
                  if (onCancel != null) {
                    onCancel!();
                  }
                  Navigator.of(context).pop();
                },
                child: Text(
                  cancelButtonText,
                  style: AppTypography.buttonText.copyWith(
                    color: indicatorColor,
                  ),
                ),
              ),
            ]
          : null,
      actionsPadding: showCancelButton
          ? const EdgeInsets.fromLTRB(16, 0, 16, 16)
          : EdgeInsets.zero,
    );
  }

  /// Shows this loading dialog
  static Future<T?> show<T>(
    BuildContext context, {
    Key? key,
    required String message,
    String title = 'Please Wait...',
    Color indicatorColor = AppColors.primaryColor,
    bool barrierDismissible = false,
    bool showCancelButton = false,
    String cancelButtonText = 'Cancel',
    VoidCallback? onCancel,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => LoadingDialog(
        key: key,
        title: title,
        message: message,
        indicatorColor: indicatorColor,
        showCancelButton: showCancelButton,
        cancelButtonText: cancelButtonText,
        onCancel: onCancel,
      ),
    );
  }
}
