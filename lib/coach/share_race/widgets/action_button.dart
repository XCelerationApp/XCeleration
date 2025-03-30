import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/typography.dart';

/// A custom action button widget

class ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final String? tooltip;

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.tooltip,
  });

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip ?? '',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: ElevatedButton(
            onPressed: () {
              if (widget.onPressed != null) {
                _controller.forward().then((_) {
                  _controller.reverse();
                  widget.onPressed!();
                });
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              backgroundColor:
                  widget.isPrimary ? AppColors.primaryColor : Colors.white,
              foregroundColor:
                  widget.isPrimary ? Colors.white : AppColors.primaryColor,
              elevation: widget.isPrimary ? 0 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: widget.isPrimary
                  ? BorderSide.none
                  : BorderSide(
                      color: AppColors.primaryColor.withOpacity(0.5), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 18,
                  color:
                      widget.isPrimary ? Colors.white : AppColors.primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.label,
                    style: AppTypography.bodyRegular.copyWith(
                      color: widget.isPrimary
                          ? Colors.white
                          : AppColors.primaryColor,
                      fontWeight:
                          widget.isPrimary ? FontWeight.w600 : FontWeight.w400,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
