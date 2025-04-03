import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/bib_records_provider.dart';
import '../controller/bib_number_controller.dart';
import 'bib_input_widget.dart';
import 'add_button_widget.dart';
import '../../../core/components/dialog_utils.dart';
import '../../../core/services/tutorial_manager.dart';

class BibListWidget extends StatefulWidget {
  final ScrollController scrollController;
  final BibNumberController controller;
  final TutorialManager tutorialManager;

  const BibListWidget({
    super.key,
    required this.scrollController,
    required this.controller,
    required this.tutorialManager,
  });

  @override
  State<BibListWidget> createState() => _BibListWidgetState();
}

class _BibListWidgetState extends State<BibListWidget> with TickerProviderStateMixin {
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
    return Consumer<BibRecordsProvider>(
      builder: (context, provider, child) {
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
                child: provider.bibRecords.isEmpty
                    ? Center(
                        child: Text(
                          'No bib numbers recorded yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: widget.scrollController,
                        itemCount: provider.bibRecords.length,
                        itemBuilder: (context, index) {
                          if (index < provider.bibRecords.length) {
                            return Dismissible(
                              key: ValueKey(provider.bibRecords[index]),
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
                                if (index >= provider.focusNodes.length) return false;
                                
                                for (var node in provider.focusNodes) {
                                  node.unfocus();
                                  node.canRequestFocus = false;
                                }
                                bool delete = await DialogUtils.showConfirmationDialog(
                                  context,
                                  title: 'Confirm Deletion',
                                  content: 'Are you sure you want to delete this bib number?',
                                );
                                widget.controller.restoreFocusability();
                                return delete;
                              },
                              onDismissed: (direction) {
                                widget.controller.onBibRecordRemoved(index);
                              },
                              child: BibInputWidget(
                                index: index,
                                record: provider.bibRecords[index],
                                onBibNumberChanged: widget.controller.handleBibNumber,
                                onSubmitted: () => widget.controller.handleBibNumber(''),
                              ),
                            );
                          }
                          return const SizedBox.shrink(); // Fallback, should never happen
                        },
                      ),
              ),
              
              // Add button - always visible at the bottom
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                child: AddButtonWidget(
                  tutorialManager: widget.tutorialManager,
                  onTap: () => widget.controller.handleBibNumber(''),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
