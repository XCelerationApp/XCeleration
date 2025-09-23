import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

Widget createSheetHandle({double height = 10.0, double width = 50.0}) {
  return Container(
    padding: const EdgeInsets.all(0),
    alignment: Alignment.topCenter,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10.0),
      child: Container(
        height: height,
        width: width,
        color: const Color(0xFFD6D6D6),
      ),
    ),
  );
}

Widget createBackArrow(BuildContext context, {VoidCallback? onBack}) {
  return IconButton(
    iconSize: 24,
    icon: const Icon(Icons.arrow_back),
    onPressed: () {
      if (onBack != null) {
        onBack();
      } else {
        Navigator.of(context).pop();
      }
    },
  );
}

Widget createSheetHeader(
  String? title, {
  double titleSize = 24,
  bool backArrow = false,
  BuildContext? context,
  VoidCallback? onBack,
}) {
  return Column(
    children: [
      createSheetHandle(height: 5, width: 50),
      const SizedBox(height: 8),
      if (title != null) ...[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (backArrow && context != null)
              createBackArrow(context, onBack: onBack),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.visible,
                softWrap: true,
              ),
            ),
            if (backArrow) const SizedBox(width: 24),
          ],
        ),
      ],
      const SizedBox(height: 16),
    ],
  );
}

Future<dynamic> sheet(
    {required BuildContext context,
    required Widget body,
    String? title,
    double titleSize = 24,
    Widget? actionButtons,
    bool showHeader = true,
    bool takeUpScreen = false,
    bool useRootNavigator = false,
    bool useBottomPadding = true}) async {

  // Ensure no underlying input keeps focus when presenting the sheet
  FocusManager.instance.primaryFocus?.unfocus();
  final result = await showModalBottomSheet(
    backgroundColor: Colors.transparent,
    context: context,
    isScrollControlled: true,
    enableDrag: true,
    useRootNavigator: useRootNavigator,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
        minHeight: takeUpScreen ? MediaQuery.of(context).size.height * 0.92 : 0,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: 8,
          left: 24,
          right: 24,
          bottom: (useBottomPadding
                  ? MediaQuery.of(context).viewInsets.bottom
                  : 0) +
              36,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHeader) createSheetHeader(title, titleSize: titleSize),
            Flexible(child: body),
            if (actionButtons != null) actionButtons,
          ],
        ),
      ),
    ),
  );

  // Dismiss any lingering focus (and keyboard) after the sheet closes
  FocusManager.instance.primaryFocus?.unfocus();
  return result;
}
