import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xceleration/core/components/dialog_utils.dart';
import 'package:xceleration/core/theme/typography.dart';

/// Actions that can be performed on a Google Sheet
enum GoogleSheetAction {
  openSheet,
  share,
  copyLink,
}

/// A button to open a Google Sheet
class GoogleSheetOpenButton extends StatelessWidget {
  final VoidCallback onPressed;

  const GoogleSheetOpenButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0F9D58),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
      ),
      child: Text(
        'Open',
        style: AppTypography.smallBodySemibold.copyWith(
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Google Sheet icon container widget
class GoogleSheetIcon extends StatelessWidget {
  final double size;
  final double iconSize;

  const GoogleSheetIcon({
    super.key,
    this.size = 28,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF0F9D58), // Google Sheets green
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.table_chart,
        color: Colors.white,
        size: iconSize,
      ),
    );
  }
}

/// Widget for the middle row that displays sheet info and open button
class GoogleSheetInfoRow extends StatelessWidget {
  final String title;
  final VoidCallback onOpenPressed;

  const GoogleSheetInfoRow({
    super.key,
    required this.title,
    required this.onOpenPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Google Sheets Icon
          const GoogleSheetIcon(),

          const SizedBox(width: 10),

          // Sheet title
          Expanded(
            child: Text(
              title,
              style: AppTypography.bodyRegular.copyWith(
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(width: 10),

          // Open button
          GoogleSheetOpenButton(
            onPressed: onOpenPressed,
          ),
        ],
      ),
    );
  }
}

/// A button to copy the Google Sheet link
class GoogleSheetActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const GoogleSheetActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 24, color: Colors.black87),
        label: Text(
          label,
          style: AppTypography.buttonText.copyWith(
            color: Colors.black87,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: const BorderSide(color: Colors.black87),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          foregroundColor: Colors.black87,
        ),
      ),
    );
  }
}

/// A button to share the Google Sheet
class GoogleSheetShareButton extends StatelessWidget {
  final VoidCallback onPressed;

  const GoogleSheetShareButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.share, size: 24, color: Colors.black87),
        label: Text(
          'Share',
          style: AppTypography.buttonText.copyWith(
            color: Colors.black87,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: const BorderSide(color: Colors.black87),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          foregroundColor: Colors.black87,
        ),
      ),
    );
  }
}

/// Row of secondary action buttons for Google Sheet dialog
class GoogleSheetActionRow extends StatelessWidget {
  final VoidCallback onCopy;
  final VoidCallback onShare;

  const GoogleSheetActionRow({
    super.key,
    required this.onCopy,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Copy Link Button
        GoogleSheetActionButton(
          label: 'Copy Link',
          icon: Icons.copy,
          onPressed: onCopy,
        ),

        const SizedBox(width: 12),

        // Share Button
        GoogleSheetActionButton(
          label: 'Share',
          icon: Icons.share,
          onPressed: onShare,
        ),
      ],
    );
  }
}

/// Main Google Sheet options dialog widget
class GoogleSheetOptionsDialog extends StatelessWidget {
  final String title;
  final Uri sheetUri;

  const GoogleSheetOptionsDialog({
    super.key,
    required this.title,
    required this.sheetUri,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Title at the top by itself
            Text(
              'Google Sheet Created!',
              style: AppTypography.titleSemibold.copyWith(
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Middle row with icon, title and button
            GoogleSheetInfoRow(
              title: title,
              onOpenPressed: () =>
                  Navigator.pop(context, GoogleSheetAction.openSheet),
            ),

            const SizedBox(height: 24),

            // Secondary actions row
            GoogleSheetActionRow(
              onCopy: () async {
                // Copy to clipboard directly without closing dialog
                await Clipboard.setData(
                    ClipboardData(text: sheetUri.toString()));
                // Let the user know the link was copied
                if (context.mounted) {
                  DialogUtils.showSuccessDialog(
                    context,
                    message: 'Copied to clipboard!',
                  );
                }
              },
              onShare: () => Navigator.pop(context, GoogleSheetAction.share),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the Google Sheet options dialog and returns the selected action
Future<GoogleSheetAction?> showGoogleSheetOptionsDialog(
  BuildContext context, {
  required String title,
  required Uri sheetUri,
}) async {
  return showDialog<GoogleSheetAction>(
    context: context,
    builder: (context) => GoogleSheetOptionsDialog(
      title: title,
      sheetUri: sheetUri,
    ),
  );
}
