import 'package:flutter/material.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'tutorial_manager.dart';

/// Configuration for a coach mark tooltip
class CoachMarkConfig {
  final String title;
  final AlignmentX alignmentX;
  final AlignmentY alignmentY;
  final String? description;
  final IconData? icon;
  final CoachMarkType type;
  final double width;
  final EdgeInsets padding;
  final Color backgroundColor;
  final Color textColor;
  final double arrowSize;
  final double elevation;

  const CoachMarkConfig({
    required this.title,
    this.alignmentX = AlignmentX.center,
    this.alignmentY = AlignmentY.bottom,
    this.description,
    this.icon,
    this.type = CoachMarkType.targeted,
    this.width = 250,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor = const Color(0xFF2196F3),
    this.textColor = Colors.white,
    this.arrowSize = 12,
    this.elevation = 8,
  });
}

/// Defines the position of the coach mark tooltip
enum CoachMarkType{
  general,
  targeted
}

/// A widget that shows a coach mark tooltip
class CoachMark extends StatefulWidget {
  final String id;
  final TutorialManager tutorialManager;
  final CoachMarkConfig config;
  final VoidCallback? onDismiss;
  final Widget child;

  const CoachMark({
    super.key,
    required this.id,
    required this.tutorialManager,
    required this.child,
    required this.config,
    this.onDismiss,
  });

  @override
  State<CoachMark> createState() => _CoachMarkState();
}

class _CoachMarkState extends State<CoachMark> {
  final GlobalKey _targetKey = GlobalKey();
  bool _hasUpdatedRect = false;

  @override
  void dispose() {
    if (widget.tutorialManager.activeCoachMark == widget.id) {
      widget.tutorialManager.setTargetRect(null);
    }
    super.dispose();
  }

  void updateTargetRect() {
    if (!mounted || _hasUpdatedRect || widget.config.type == CoachMarkType.general) return;
    
    final RenderBox? renderBox = _targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Rect rect = renderBox.localToGlobal(Offset.zero) & renderBox.size;
    
    if (widget.tutorialManager.activeCoachMark == widget.id) {
      widget.tutorialManager.setTargetRect(rect);
      _hasUpdatedRect = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.tutorialManager,
      builder: (context, _) {
        final isVisible = widget.tutorialManager.activeCoachMark == widget.id;
        
        if (!isVisible) {
          _hasUpdatedRect = false;
          return widget.child;
        }

        // Create a portal target for the tooltip and child
        final result = PortalTarget(
          visible: true,
          anchor: Aligned(
            follower: _getFollowerAlignment(),
            target: _getTargetAlignment(),
            offset: _getOffset(),
          ),
          portalFollower: GestureDetector(
            onTap: () => widget.tutorialManager.nextTutorial(),
            child: Material(
              type: MaterialType.transparency,
              child: _buildCoachMark(),
            ),
          ),
          child: Container(
            key: _targetKey,
            child: widget.child,
          ),
        );

        // Reset rect and schedule update when becoming visible
        if (!_hasUpdatedRect) {
          // Use microtask to ensure we update in this frame
          Future.microtask(() {
            if (!mounted) return;
            updateTargetRect();
          });
        }

        return result;
      },
    );
  }

  Alignment _getFollowerAlignment() {
    if (widget.config.type == CoachMarkType.general) {
      return Alignment.center;
    }

    switch (widget.config.alignmentX) {
      case AlignmentX.left:
        switch (widget.config.alignmentY) {
          case AlignmentY.top:
            return Alignment.bottomRight;
          case AlignmentY.center:
            return Alignment.centerRight;
          case AlignmentY.bottom:
            return Alignment.topRight;
        }
      case AlignmentX.center:
        switch (widget.config.alignmentY) {
          case AlignmentY.top:
            return Alignment.bottomCenter;
          case AlignmentY.center:
            return Alignment.center;
          case AlignmentY.bottom:
            return Alignment.topCenter;
        }
      case AlignmentX.right:
        switch (widget.config.alignmentY) {
          case AlignmentY.top:
            return Alignment.bottomLeft;
          case AlignmentY.center:
            return Alignment.centerLeft;
          case AlignmentY.bottom:
            return Alignment.topLeft;
        }
    }
  }

  Alignment _getTargetAlignment() {
    if (widget.config.type == CoachMarkType.general) {
      return Alignment.center;
    }

    switch (widget.config.alignmentY) {
      case AlignmentY.top:
        return Alignment.topCenter;
      case AlignmentY.center:
        return Alignment.center;
      case AlignmentY.bottom:
        return Alignment.bottomCenter;
    }
  }

  Offset _getOffset() {
    if (widget.config.type == CoachMarkType.general) {
      return Offset.zero;
    }

    final double xOffset = widget.config.alignmentX == AlignmentX.left 
        ? 30 + widget.config.arrowSize 
        : (widget.config.alignmentX == AlignmentX.right ? -(30 + widget.config.arrowSize) : 0);
    
    final double yOffset = widget.config.alignmentY == AlignmentY.top 
        ? -8 
        : (widget.config.alignmentY == AlignmentY.bottom ? 8 : 0);

    return Offset(xOffset, yOffset);
  }

  Widget _buildCoachMark() {
    return SizedBox(
      width: widget.config.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.config.type != CoachMarkType.general && widget.config.alignmentY == AlignmentY.bottom) ...[
            buildArrow(widget.config.arrowSize, widget.config.width, widget.config.alignmentX, widget.config.alignmentY, widget.config.backgroundColor),
          ],
          Container(
            padding: widget.config.padding,
            decoration: BoxDecoration(
              color: widget.config.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              // boxShadow: [
              //   BoxShadow(
              //     color: Colors.black.withOpacity(0.2),
              //     blurRadius: config.elevation,
              //     offset: const Offset(0, 4),
              //   ),
              // ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.config.icon != null) ...[
                  Icon(
                    widget.config.icon,
                    color: widget.config.textColor,
                    size: 24,
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  widget.config.title,
                  style: TextStyle(
                    color: widget.config.textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.25,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget.config.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.config.description!,
                    style: TextStyle(
                      color: widget.config.textColor.withAlpha((0.9 * 255).round()),
                      fontSize: 12,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          if (widget.config.type != CoachMarkType.general && widget.config.alignmentY == AlignmentY.top) ...[
            buildArrow(widget.config.arrowSize, widget.config.width, widget.config.alignmentX, widget.config.alignmentY, widget.config.backgroundColor),
          ],
        ]
      )
    );
  }
}

Widget buildArrow(double arrowSize, double width, AlignmentX alignmentX, AlignmentY alignmentY, Color backgroundColor) {
  return SizedBox(
    height: arrowSize,
    width: width,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          right: alignmentX == AlignmentX.left ? 30 : null,
          left: alignmentX == AlignmentX.right ? 30 : null,
          child: CustomPaint(
            size: Size(arrowSize * 2, arrowSize),
            painter: ArrowPainter(
              color: backgroundColor,
              alignmentY: alignmentY,
            ),
          ),
        ),
      ],
    ),
  );
}

class ArrowPainter extends CustomPainter {
  final Color color;
  final AlignmentY alignmentY;

  ArrowPainter({required this.color, required this.alignmentY});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    Path path;

    if (alignmentY == AlignmentY.top) {
      path = Path()
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0)
        ..close();
    } else {
      path = Path()
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ArrowPainter oldDelegate) => color != oldDelegate.color || alignmentY != oldDelegate.alignmentY;
}

enum AlignmentX { left, center, right }
enum AlignmentY { top, center, bottom }