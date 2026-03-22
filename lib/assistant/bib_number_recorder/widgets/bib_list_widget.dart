import 'package:flutter/material.dart';
import '../controller/bib_number_controller.dart';
import '../model/bib_datum_record.dart';
import 'bib_input_widget.dart';
import '../../../core/components/dialog_utils.dart';

class BibListWidget extends StatefulWidget {
  final BibNumberController controller;

  const BibListWidget({
    super.key,
    required this.controller,
  });

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
    if (newCount != _lastKnownCount || newRaceStopped != _lastKnownRaceStopped) {
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
              itemCount: widget.controller.bibRecords.length,
              itemBuilder: (context, index) {
                return Dismissible(
                  key: ValueKey(widget.controller.controllers[index]),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16.0),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                  ),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (direction) async {
                    if (index >= widget.controller.focusNodes.length) {
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
          const SizedBox(height: 4)
        ],
      ),
    );
  }
}
