import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_border_radius.dart';
import '../theme/app_opacity.dart';
import '../theme/typography.dart';
import 'package:xceleration/core/utils/color_utils.dart';

/// Private base widget shared by [CircularButton] and [RoundedRectangleButton].
/// Encapsulates the SizedBox → decorated Container → transparent ElevatedButton → Text pattern
/// common to both shaped button variants.
class _ShapeButton extends StatelessWidget {
  final double width;
  final double height;
  final VoidCallback? onPressed;
  final String text;
  final double fontSize;
  final FontWeight? fontWeight;
  final BoxDecoration decoration;
  final OutlinedBorder buttonShape;

  const _ShapeButton({
    required this.width,
    required this.height,
    required this.onPressed,
    required this.text,
    required this.fontSize,
    this.fontWeight,
    required this.decoration,
    required this.buttonShape,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: decoration,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shape: buttonShape,
            padding: EdgeInsets.zero,
            elevation: 0,
          ),
          child: Text(
            text,
            style: fontSize <= 16
                ? AppTypography.bodySemibold.copyWith(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                  )
                : AppTypography.titleSemibold.copyWith(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                  ),
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}

/// Icon-only button for compact UI elements
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  final double iconSize;
  final double elevation;
  final bool isEnabled;

  const CircleIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = 48.0,
    this.iconSize = 24.0,
    this.elevation = 1.0,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor = backgroundColor ?? Colors.white;
    final effectiveIconColor = iconColor ?? AppColors.primaryColor;

    return SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: elevation > 0
              ? [
                  BoxShadow(
                    color: ColorUtils.withOpacity(Colors.black, AppOpacity.light),
                    spreadRadius: 0,
                    blurRadius: elevation * 2,
                    offset: elevation > 0 ? const Offset(0, 2) : Offset.zero,
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: isEnabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: effectiveBackgroundColor,
            foregroundColor: effectiveIconColor,
            disabledBackgroundColor:
                ColorUtils.withOpacity(effectiveBackgroundColor, AppOpacity.solid),
            disabledForegroundColor:
                ColorUtils.withOpacity(effectiveIconColor, AppOpacity.solid),
            padding: EdgeInsets.zero,
            shape: const CircleBorder(),
            elevation: 0,
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: effectiveIconColor,
          ),
        ),
      ),
    );
  }
}

/// Circular button with custom background and border.
///
/// Intentionally separate from [ActionButton]: [CircularButton] and [RoundedRectangleButton]
/// use a different visual structure (transparent ElevatedButton inside a decorated container)
/// suited for fixed-shape, colour-filled timing controls — not the flexible text/icon
/// button pattern of [ActionButton].
class CircularButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final Color color;
  final double fontSize;
  final FontWeight? fontWeight;
  final double elevation;

  const CircularButton({
    required this.onPressed,
    required this.text,
    required this.color,
    this.fontSize = 20,
    this.fontWeight,
    this.elevation = 0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return _ShapeButton(
      width: 70,
      height: 70,
      onPressed: onPressed,
      text: text,
      fontSize: fontSize,
      fontWeight: fontWeight,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: AppColors.backgroundColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: color,
            spreadRadius: 2,
            blurRadius: elevation > 0 ? 4 : 0,
            offset: elevation > 0 ? const Offset(0, 2) : Offset.zero,
          ),
        ],
      ),
      buttonShape: const CircleBorder(),
    );
  }
}

/// Rounded rectangle button with custom width, height, and color.
/// See [CircularButton] for an explanation of why these two widgets are separate from [ActionButton].
class RoundedRectangleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final Color color;
  final double fontSize;
  final double width;
  final double height;

  const RoundedRectangleButton({
    this.onPressed,
    required this.text,
    required this.color,
    required this.width,
    required this.height,
    this.fontSize = 20,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return _ShapeButton(
      width: width,
      height: height,
      onPressed: onPressed,
      text: text,
      fontSize: fontSize,
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        color: color,
        border: Border.all(color: AppColors.backgroundColor, width: 2),
        boxShadow: [BoxShadow(color: color, spreadRadius: 2)],
        borderRadius:
            const BorderRadius.all(Radius.circular(AppBorderRadius.full)),
      ),
      buttonShape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.all(Radius.circular(AppBorderRadius.full)),
      ),
    );
  }
}
