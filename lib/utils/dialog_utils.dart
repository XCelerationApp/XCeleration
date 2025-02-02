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
    final overlay = Overlay.of(context);
  final overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.of(context).viewInsets.top + 50, // Position it at the top
      left: MediaQuery.of(context).size.width * 0.05,
      right: MediaQuery.of(context).size.width * 0.05,
      child: Material(
        elevation: 6.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          color: Colors.red,
          child: Text(
            message,
            style: const TextStyle(color: Colors.white, fontSize: 20),
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
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text(message),
    //     duration: Duration(seconds: 3),
    //     // action: SnackBarAction(
    //     //   label: 'OK',
    //     //   onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
    //     // ),
    //   ),
    // );
  // }
}