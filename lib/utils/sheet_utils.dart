import 'package:flutter/material.dart';
import 'app_colors.dart';

Widget createSheetHandle({double height = 10.0, double width = 50.0}) {
  return Container(
    padding: const EdgeInsets.all(0),
    alignment: Alignment.topCenter,
    // width: 50.0,
    // decoration: BoxDecoration(
    //   border: Border(
    //     top: BorderSide(
    //       width: 5.0,
    //       color: Colors.transparent,
    //       style: BorderStyle.solid,
    //     ),
    //     bottom: BorderSide(
    //       width: 5.0,
    //       color: Colors.transparent,
    //       style: BorderStyle.solid,
    //     ),
    //   ),
    // ),
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

// Widget createBackArrowBar(BuildContext context) {
//   return Container(
//     alignment: Alignment.topLeft,
//     // width: 50.0,
//     decoration: BoxDecoration(
//       border: Border(
//         top: BorderSide(
//           width: 5.0,
//           color: Colors.transparent,
//           style: BorderStyle.solid,
//         ),
//         bottom: BorderSide(
//           width: 5.0,
//           color: Colors.transparent,
//           style: BorderStyle.solid,
//         ),
//       ),
//     ),
//     child: createBackArrow(context),
//   );
// }

Widget createSheetHeader(String title, {
  double titleSize = 24,
  bool backArrow = false,
  BuildContext? context,
  VoidCallback? onBack,
}) {
  return Column(
    children: [
      createSheetHandle(height: 5, width: 50),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          backArrow && context != null
              ? createBackArrow(context, onBack: onBack)
              : const SizedBox.shrink(),
          Text(
            title,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w600,
              color: AppColors.darkColor,
            ),
            textAlign: TextAlign.center,
          ),
          backArrow ? const SizedBox(width: 24) : const SizedBox.shrink(),
        ],
      ),
      const SizedBox(height: 16),
    ],
  );
}

Future<dynamic> sheet({required BuildContext context, required Widget body, required String title, double titleSize = 24, Widget? action_buttons, bool showHeader = true, bool takeUpScreen = false}) async {
  return await showModalBottomSheet(
    backgroundColor: AppColors.backgroundColor,
    context: context,
    isScrollControlled: true,
    enableDrag: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(16),
      ),
    ),
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
        minHeight: takeUpScreen ? MediaQuery.of(context).size.height * 0.92 : 0,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: 8,
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 36,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHeader) createSheetHeader(title, titleSize: titleSize),
            Flexible(child: body),
            if (action_buttons != null) action_buttons,
          ],
        ),
      ),
    ),
  );
}