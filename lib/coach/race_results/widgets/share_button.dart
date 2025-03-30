import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';


class ShareButton extends StatelessWidget {
  final Function()? onPressed;
  const ShareButton({super.key, this.onPressed});
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: AppColors.primaryColor,
      child: const Icon(Icons.ios_share, color: Colors.white),
    );
  }
}
  