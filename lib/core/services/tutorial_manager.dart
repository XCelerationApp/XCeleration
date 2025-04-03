import 'package:flutter/material.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

/// Manages the tutorial system and coach marks
class TutorialManager extends ChangeNotifier {
  TutorialManager();

  final Map<String, bool> _hasSeenTutorial = {};
  String? _activeCoachMark;
  List<String> _tutorialQueue = [];
  Rect? _targetRect;

  String? get activeCoachMark => _activeCoachMark;
  Rect? get targetRect => _targetRect;

  /// Set the target rect for the current coach mark
  void setTargetRect(Rect? rect) {
    if (_targetRect != rect) {
      _targetRect = rect;
      notifyListeners();
    }
  }

  /// Start a tutorial sequence with the given coach mark IDs
  void startTutorial(List<String> coachMarkIds) async {
    _tutorialQueue = [];

    for (final id in coachMarkIds) {
      final hasSeen = await hasSeenTutorial(id);
      if (!hasSeen) {
        _tutorialQueue.add(id);
      }
    }
    await Future.delayed(const Duration(milliseconds: 150));

    if (_tutorialQueue.isNotEmpty) {
      _activeCoachMark = _tutorialQueue.first;
      notifyListeners();
    }
  }

  /// Advance to the next tutorial in the sequence
  Future<void> nextTutorial() async {
    if (_activeCoachMark == null) return;

    await _markTutorialAsSeen(_activeCoachMark!);

    // Check if the queue has items before removing
    if (_tutorialQueue.isNotEmpty) {
      _tutorialQueue.removeAt(0);
    }

    // Always clear the target rect between tutorials
    _targetRect = null;
    notifyListeners();

    // Small delay to ensure overlay updates
    await Future.delayed(const Duration(milliseconds: 50));

    if (_tutorialQueue.isEmpty) {
      _activeCoachMark = null;
    } else {
      _activeCoachMark = _tutorialQueue.first;
    }
    notifyListeners();
  }

  /// Check if a tutorial has been seen
  Future<bool> hasSeenTutorial(String id) async {
    if (Platform.isMacOS) {
      return _hasSeenTutorial[id] ?? false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(id) ?? false;
    } catch (e) {
      debugPrint('Error checking if tutorial has been seen: $e');
      return false;
    }
  }

  /// Mark a tutorial as seen
  Future<void> _markTutorialAsSeen(String id) async {
    if (Platform.isMacOS) {
      _hasSeenTutorial[id] = true;
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(id, true);
    } catch (e) {
      debugPrint('Error marking tutorial as seen: $e');
    }
  }
}

/// A widget that wraps the app content and manages coach marks
class TutorialRoot extends StatefulWidget {
  final Widget child;
  final TutorialManager tutorialManager;

  const TutorialRoot({
    super.key,
    required this.child,
    required this.tutorialManager,
  });

  @override
  State<TutorialRoot> createState() => _TutorialRootState();
}

class _TutorialRootState extends State<TutorialRoot> {
  @override
  Widget build(BuildContext context) {
    return Portal(
      child: Stack(
        children: [
          // Layer 1: Main content
          widget.child,

          // Layer 2: Semi-transparent overlay with cutout
          ListenableBuilder(
            listenable: widget.tutorialManager,
            builder: (context, _) {
              final activeCoachMark = widget.tutorialManager.activeCoachMark;
              final targetRect = widget.tutorialManager.targetRect;
              if (activeCoachMark == null) return const SizedBox.shrink();

              return Positioned.fill(
                child: CustomPaint(
                  painter: OverlayPainter(
                    targetRect: targetRect,
                    opacity: 0.5,
                  ),
                ),
              );
            },
          ),

          // Layer 3: Transparent overlay for gestures
          ListenableBuilder(
            listenable: widget.tutorialManager,
            builder: (context, _) {
              final activeCoachMark = widget.tutorialManager.activeCoachMark;
              if (activeCoachMark == null) return const SizedBox.shrink();

              return Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => widget.tutorialManager.nextTutorial(),
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Custom painter that creates a semi-transparent overlay with a hole cut out
class OverlayPainter extends CustomPainter {
  final Rect? targetRect;
  final double opacity;
  static const double padding = 4.0;
  static const double borderRadius = 8.0;

  OverlayPainter({
    this.targetRect,
    this.opacity = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withAlpha((opacity * 255).round())
      ..style = PaintingStyle.fill;

    if (targetRect == null) {
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }

    // Create a padded rect that doesn't exceed screen bounds
    final paddedRect = Rect.fromLTRB(
      (targetRect!.left - padding).clamp(0, size.width),
      (targetRect!.top - padding).clamp(0, size.height),
      (targetRect!.right + padding).clamp(0, size.width),
      (targetRect!.bottom + padding).clamp(0, size.height),
    );

    // Create a path for the entire screen
    final backgroundPath = Path()..addRect(Offset.zero & size);

    // Create a hole path for the target
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        paddedRect,
        const Radius.circular(borderRadius),
      ));

    // Combine the paths to create the overlay with hole
    final path = Path.combine(
      PathOperation.difference,
      backgroundPath,
      holePath,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(OverlayPainter oldDelegate) {
    return targetRect != oldDelegate.targetRect ||
        opacity != oldDelegate.opacity;
  }
}
