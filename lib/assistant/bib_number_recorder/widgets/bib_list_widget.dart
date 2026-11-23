import '../../../core/theme/typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import '../controller/bib_number_controller.dart';
import '../model/bib_datum_record.dart';
import 'bib_input_widget.dart';
import '../../../core/components/dialog_utils.dart';

class BibListWidget extends StatefulWidget {
  final BibNumberController controller;

  const BibListWidget({super.key, required this.controller});

  @override
  State<BibListWidget> createState() => _BibListWidgetState();
}

class _BibListWidgetState extends State<BibListWidget>
    with TickerProviderStateMixin {
  final Map<int, AnimationController> _animationControllers = {};

  // Track the last-known values that require a full-list rebuild.
  int _lastKnownCount = 0;
  bool _lastKnownRaceStopped = false;

  @override
  void initState() {
    super.initState();
    _lastKnownCount = widget.controller.bibRecords.length;
    _lastKnownRaceStopped = widget.controller.raceStopped;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    for (var controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onControllerChanged() {
    final newCount = widget.controller.bibRecords.length;
    final newRaceStopped = widget.controller.raceStopped;
    if (newCount != _lastKnownCount ||
        newRaceStopped != _lastKnownRaceStopped) {
      setState(() {
        _lastKnownCount = newCount;
        _lastKnownRaceStopped = newRaceStopped;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: widget.controller.scrollController,
              // The screen already clears the notch; without this the list adds
              // the safe-area gap again above the first row.
              padding: EdgeInsets.zero,
              itemCount: widget.controller.bibRecords.length,
              itemBuilder: (context, index) {
                final recording = !widget.controller.raceStopped;
                const delete = _SwipeAction(
                  icon: Icons.delete,
                  label: 'Delete',
                  color: AppColors.redColor,
                  alignment: Alignment.centerRight,
                );
                return Dismissible(
                  key: ValueKey(widget.controller.controllers[index]),
                  // Swipe right to put in a runner who was missed above this
                  // one, as when checking against a written list; left to
                  // delete. Inserting needs a bib typed, so only while
                  // recording.
                  background: recording
                      ? const _SwipeAction(
                          icon: Icons.add,
                          label: 'Insert above',
                          color: AppColors.primaryColor,
                          alignment: Alignment.centerLeft,
                        )
                      : delete,
                  secondaryBackground: recording ? delete : null,
                  direction: recording
                      ? DismissDirection.horizontal
                      : DismissDirection.endToStart,
                  confirmDismiss: (direction) async {
                    if (index >= widget.controller.focusNodes.length) {
                      return false;
                    }
                    if (direction == DismissDirection.startToEnd) {
                      await widget.controller.insertBibAbove(index);
                      return false;
                    }

                    for (var node in widget.controller.focusNodes) {
                      node.unfocus();
                      node.canRequestFocus = false;
                    }
                    bool delete = await DialogUtils.showConfirmationDialog(
                      context,
                      title: 'Confirm Deletion',
                      content:
                          'Are you sure you want to delete this bib number?',
                    );
                    widget.controller.restoreFocusability();
                    return delete;
                  },
                  onDismissed: (direction) {
                    widget.controller.removeBibRecord(index);
                  },
                  child: ValueListenableBuilder<BibDatumRecord>(
                    valueListenable: widget.controller.rowNotifiers[index],
                    builder: (context, record, _) => BibInputWidget(
                      key: ValueKey('bib_input_$index'),
                      index: index,
                      record: record,
                      controller: widget.controller,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// What a swipe on a bib does, shown behind the row as it slides.
class _SwipeAction extends StatelessWidget {
  const _SwipeAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.alignment,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: AppTypography.smallBodySemibold.copyWith(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
