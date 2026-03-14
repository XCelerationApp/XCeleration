import 'package:flutter/material.dart';
import '../controller/bib_number_controller.dart';
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

  @override
  void dispose() {
    // Dispose all animation controllers
    for (var controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Add unfocus behavior when tapping outside textfields
      onTap: () {
        // Unfocus any active text fields when tapping elsewhere
        FocusScope.of(context).unfocus();
      },
      child: Column(
        children: [
          // List of bib records
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
                  child: BibInputWidget(
                    index: index,
                    controller: widget.controller,
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
