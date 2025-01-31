import 'package:flutter/material.dart';

class DialogUtils {
  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = 'Yes',
    String cancelText = 'No',
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    ) ?? false;
  }

  static void showErrorDialog(
    BuildContext context, {
    required String message,
    String? title,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 3),
        // action: SnackBarAction(
        //   label: 'OK',
        //   onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        // ),
      ),
    );
  }
}