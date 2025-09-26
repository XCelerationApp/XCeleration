import 'package:flutter/material.dart';
import '../../../../core/components/button_components.dart';

/// A custom animated action button widget for share race functionality
class ShareActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final String? tooltip;

  const ShareActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.tooltip,
  });

  @override
  State<ShareActionButton> createState() => _ShareActionButtonState();
}

class _ShareActionButtonState extends State<ShareActionButton>
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
          child: widget.isPrimary
              ? PrimaryButton(
                  text: widget.label,
                  icon: widget.icon,
                  borderRadius: 12,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  iconSize: 18,
                  onPressed: () {
                    if (widget.onPressed != null) {
                      _controller.forward().then((_) {
                        _controller.reverse();
                        widget.onPressed!();
                      });
                    }
                  },
                )
              : SecondaryButton(
                  text: widget.label,
                  icon: widget.icon,
                  borderRadius: 12,
                  elevation: 2,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  iconSize: 18,
                  onPressed: () {
                    if (widget.onPressed != null) {
                      _controller.forward().then((_) {
                        _controller.reverse();
                        widget.onPressed!();
                      });
                    }
                  },
                ),
        ),
      ),
    );
  }
}
