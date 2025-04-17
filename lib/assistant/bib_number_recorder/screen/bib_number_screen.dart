import 'package:flutter/material.dart';
import '../../../core/services/tutorial_manager.dart';
import '../../../shared/role_bar/models/role_enums.dart';
import '../../../shared/role_bar/role_bar.dart';
import '../controller/bib_number_controller.dart';
import '../widget/bib_list_widget.dart';
import '../widget/race_info_header_widget.dart';
import '../widget/race_controls_widget.dart';
import '../widget/keyboard_accessory_bar.dart';

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
      child: TutorialRoot(
        tutorialManager: _controller.tutorialManager,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Scaffold(
                resizeToAvoidBottomInset: true,
                body: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(                      
                        children: [
                          RoleBar(
                            currentRole: Role.bibRecorder,
                            tutorialManager: _controller.tutorialManager,
                          ),
                          const SizedBox(height: 16.0),

                          RaceInfoHeaderWidget(controller: _controller),

                          const SizedBox(height: 16),

                          RaceControlsWidget(controller: _controller),
                          const SizedBox(height: 8),
                        ]
                      )
                    ),
                    
                    // Bib input list section - moved outside the inner Column
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: BibListWidget(
                          controller: _controller,
                        ),
                      ),
                    ),

                    // Keyboard accessory bar for mobile devices
                    KeyboardAccessoryBar(
                      controller: _controller,
                      onDone: () => FocusScope.of(context).unfocus(),
                    ),
                  ]
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
