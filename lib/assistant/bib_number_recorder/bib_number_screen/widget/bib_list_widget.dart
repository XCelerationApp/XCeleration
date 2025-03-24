import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/bib_records_provider.dart';
import '../controller/bib_number_controller.dart';
import './bib_input_widget.dart';
import './add_button_widget.dart';
import '../../../../core/components/dialog_utils.dart';
import '../../../../core/services/tutorial_manager.dart';

class BibListWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Consumer<BibRecordsProvider>(
      builder: (context, provider, child) {
        return ListView.builder(
          controller: scrollController,
          itemCount: provider.bibRecords.length + 1,
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
                  for (var node in provider.focusNodes) {
                    node.unfocus();
                    node.canRequestFocus = false;
                  }
                  bool delete = await DialogUtils.showConfirmationDialog(
                    context,
                    title: 'Confirm Deletion',
                    content: 'Are you sure you want to delete this bib number?',
                  );
                  controller.restoreFocusability();
                  return delete;
                },
                onDismissed: (direction) {
                  controller.onBibRecordRemoved(index);
                },
                child: BibInputWidget(
                  index: index,
                  record: provider.bibRecords[index],
                  onBibNumberChanged: controller.handleBibNumber,
                  onSubmitted: () => controller.handleBibNumber(''),
                ),
              );
            }
            return AddButtonWidget(
              tutorialManager: tutorialManager,
              onTap: () => controller.handleBibNumber(''),
            );
          },
        );
      },
    );
  }
}
