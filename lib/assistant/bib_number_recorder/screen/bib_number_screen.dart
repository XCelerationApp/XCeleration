import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../model/bib_records_provider.dart';
import '../controller/bib_number_controller.dart';
import '../widget/bottom_action_buttons_widget.dart';
import '../widget/keyboard_accessory_bar.dart';
import '../widget/stats_header_widget.dart';
import '../widget/bib_list_widget.dart';
import '../../../core/components/dialog_utils.dart';
import '../../../core/services/tutorial_manager.dart';
import '../../../shared/role_functions.dart';


class BibNumberScreen extends StatefulWidget {
  const BibNumberScreen({super.key});

  @override
  State<BibNumberScreen> createState() => _BibNumberScreenState();
}

class _BibNumberScreenState extends State<BibNumberScreen> {

  late BibNumberController _controller;

  @override
  void initState() {
    super.initState();
    _controller = BibNumberController(
      context: context,
    );
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      behavior: HitTestBehavior.translucent,
      child: WillPopScope(
        onWillPop: () async {
          // Show confirmation dialog
          bool shouldPop = await DialogUtils.showConfirmationDialog(
            context,
            title: 'Leave Bib Number Screen?',
            content:
                'All bib numbers will be lost if you leave this screen. Do you want to continue?',
            confirmText: 'Continue',
            cancelText: 'Stay',
          );
          return shouldPop;
        },
        child: TutorialRoot(
          tutorialManager: _controller.tutorialManager,
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Scaffold(
              resizeToAvoidBottomInset: true,
              body: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                child: Column(
                  children: [
                    buildRoleBar(context, 'bib recorder', _controller.tutorialManager),
                    // Stats header with bib count and runner stats
                    StatsHeaderWidget(
                      runners: _controller.runners,
                      model: _controller.model,
                      onReset: () => _controller.resetLoadedRunners(context),
                    ),
                    // Bib input list section
                    Expanded(
                      child: BibListWidget(
                        scrollController: _controller.scrollController,
                        controller: _controller,
                        tutorialManager: _controller.tutorialManager,
                      ),
                    ),
                    // Action buttons at the bottom
                    Consumer<BibRecordsProvider>(
                      builder: (context, provider, _) {
                        return provider.isKeyboardVisible
                            ? const SizedBox.shrink()
                            : BottomActionButtonsWidget(
                                onShareBibNumbers: _controller.showShareBibNumbersPopup,
                              );
                      },
                    ),
                    // Keyboard accessory bar for mobile devices
                    Consumer<BibRecordsProvider>(
                      builder: (context, provider, _) {
                        if (!(Platform.isIOS || Platform.isAndroid) ||
                            !provider.isKeyboardVisible ||
                            provider.bibRecords.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return KeyboardAccessoryBar(
                          onDone: () => FocusScope.of(context).unfocus(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
