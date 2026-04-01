import 'package:flutter/material.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';

class OverflowMenuItem {
  const OverflowMenuItem({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool danger;
}

/// A ⋮ button that shows a positioned menu via [OverlayEntry] so that
/// tapping anywhere outside the menu dismisses it.
class OverflowMenuButton extends StatefulWidget {
  const OverflowMenuButton({super.key, required this.items});

  final List<OverflowMenuItem> items;

  @override
  State<OverflowMenuButton> createState() => _OverflowMenuButtonState();
}

class _OverflowMenuButtonState extends State<OverflowMenuButton> {
  OverlayEntry? _overlay;

  bool get _isOpen => _overlay != null;

  void _toggle(BuildContext context) {
    if (_isOpen) {
      _close();
    } else {
      _open(context);
    }
  }

  void _open(BuildContext context) {
    final renderBox = context.findRenderObject()! as RenderBox;
    final buttonPos = renderBox.localToGlobal(Offset.zero);
    final buttonSize = renderBox.size;

    _overlay = OverlayEntry(
      builder: (overlayContext) {
        final screenSize = MediaQuery.of(overlayContext).size;
        const menuWidth = 210.0;
        final right = screenSize.width - buttonPos.dx - buttonSize.width;
        final bottom = screenSize.height - buttonPos.dy + AppSpacing.sm;

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
              ),
            ),
            Positioned(
              right: right,
              bottom: bottom,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                elevation: 8,
                shadowColor: Colors.black26,
                child: SizedBox(
                  width: menuWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.items.asMap().entries.map((e) {
                      final i = e.key;
                      final item = e.value;
                      return GestureDetector(
                        onTap: () {
                          _close();
                          item.onTap();
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            border: i < widget.items.length - 1
                                ? const Border(
                                    bottom: BorderSide(
                                      color: AppColors.surfaceColor,
                                    ),
                                  )
                                : null,
                          ),
                          child: Text(
                            item.label,
                            style: AppTypography.smallBodySemibold.copyWith(
                              color: item.danger
                                  ? AppColors.redColor
                                  : AppColors.darkColor,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlay!);
    setState(() {});
  }

  void _close() {
    _overlay?.remove();
    _overlay?.dispose();
    _overlay = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _overlay?.remove();
    _overlay?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _toggle(context),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: _isOpen ? AppColors.selectedRoleColor : AppColors.surfaceColor,
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          border: Border.all(
            color: _isOpen ? AppColors.primaryColor : AppColors.borderColor,
          ),
        ),
        child: Center(
          child: Text(
            '⋮',
            style: AppTypography.titleRegular.copyWith(
              color: AppColors.mediumColor,
            ),
          ),
        ),
      ),
    );
  }
}
