import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart' show RunnerRecord;
import 'package:xcelerate/utils/database_helper.dart';
import 'dart:io';
import '../model/bib_number_model.dart';
import '../model/bib_records_provider.dart';
import '../controller/bib_number_controller.dart';
import '../widget/bottom_action_buttons_widget.dart';
import '../widget/keyboard_accessory_bar.dart';
import '../widget/stats_header_widget.dart';
import '../widget/bib_list_widget.dart';
import '../../../core/components/dialog_utils.dart';
import '../../../core/components/device_connection_widget.dart';
import '../../../core/services/device_connection_service.dart';
import '../../../core/services/tutorial_manager.dart';
import '../../../utils/enums.dart';
import '../../../utils/sheet_utils.dart';
import '../../../shared/role_functions.dart';
import '../../../utils/encode_utils.dart';

class BibNumberScreen extends StatefulWidget {
  const BibNumberScreen({super.key});

  @override
  State<BibNumberScreen> createState() => _BibNumberScreenState();
}

class _BibNumberScreenState extends State<BibNumberScreen> {
  final List<RunnerRecord> _runners = [];
  DevicesManager devices = DeviceConnectionService.createDevices(
    DeviceName.bibRecorder,
    DeviceType.browserDevice,
  );

  final ScrollController _scrollController = ScrollController();
  final tutorialManager = TutorialManager();

  // Store provider reference for safe disposal
  late BibRecordsProvider _providerReference;
  late BibNumberModel _model;
  late BibNumberController _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _providerReference = Provider.of<BibRecordsProvider>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    _model = BibNumberModel(
      initialRunners: _runners, 
      initialDevices: devices
    );
    
    _controller = BibNumberController(
      context: context,
      runners: _runners,
      scrollController: _scrollController,
      devices: devices,
    );
    
    _checkForRunners();
  }

  void _setupTutorials() {
    tutorialManager.startTutorial([
      // 'swipe_tutorial',
      'role_bar_tutorial',
      'add_button_tutorial'
    ]);
  }

  Future<void> _checkForRunners() async {
    // debugPrint('Checking for runners');
    // debugPrint('Checking for runners');
    // debugPrint((await DatabaseHelper.instance.getAllRaces()).map((race) => race.raceId).toString());
    // _runners.addAll(await DatabaseHelper.instance.getRaceRunners(3));
    // _runners.addAll(await DatabaseHelper.instance.getRaceRunners(2));
    // _runners.addAll(await DatabaseHelper.instance.getRaceRunners(1));
    // setState(() {});
    return;
    if (_runners.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('No Runners Loaded'),
              content: const Text('There are no runners loaded in the system. Please load runners to continue.'),
              actions: [
                TextButton(
                  child: const Text('Return to Home'),
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
                TextButton(
                  child: const Text('Load Runners'),
                  onPressed: () async {
                    sheet(
                      context: context,
                      title: 'Load Runners',
                      body: deviceConnectionWidget(
                        context,
                        _controller.devices,
                        callback: () {
                          Navigator.pop(context);
                          print('popped sheet');
                          loadRunners();
                        },
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      });
    }
  }

  Future<void> loadRunners() async {
    final data = devices.coach?.data;
    
    if (data != null) {
      try {
        // Process data outside of setState
        final runners = await decodeEncodedRunners(data, context);
        
        if (runners == null || runners.isEmpty) {
          DialogUtils.showErrorDialog(context, 
            message: 'Invalid data received from bib recorder. Please try again.');
          return;
        }
        
        final runnerInCorrectFormat = runners.every((runner) => 
          runner.bib.isNotEmpty && 
          runner.name.isNotEmpty && 
          runner.school.isNotEmpty && 
          runner.grade > 0);
        
        if (!runnerInCorrectFormat) {
          DialogUtils.showErrorDialog(context, 
            message: 'Invalid data format received from bib recorder. Please try again.');
          return;
        }

        // Update state after async operations are complete
        setState(() {
          if (_runners.isNotEmpty) _runners.clear();
          _runners.addAll(runners);
        });
        
        debugPrint('Runners loaded: $_runners');
        
        // Close dialog and handle UI updates after state is set
        if (_runners.isNotEmpty && mounted) {
          // Close the "No Runners Loaded" dialog
          Navigator.of(context).pop();
          
          // Setup tutorials after UI has settled
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _setupTutorials();
          });
            
          // Reset the bib number field
          _controller.handleBibNumber('');
        }
      } catch (e) {
        debugPrint('Error loading runners: $e');
        DialogUtils.showErrorDialog(context, 
          message: 'Error processing runner data: $e');
      }
    } else {
      DialogUtils.showErrorDialog(context, 
        message: 'No data received from bib recorder. Please try again.');
    }
  }

  Future<void> _showShareBibNumbersPopup() async {
    // Clear all focus nodes to prevent focus restoration
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    for (var node in provider.focusNodes) {
      node.unfocus();
      // Disable focus restoration for this node
      node.canRequestFocus = false;
    }

    bool confirmed = await _controller.cleanEmptyRecords();
    if (!confirmed) {
      _controller.restoreFocusability();
      return;
    }
    
    confirmed = await _controller.checkDuplicateRecords();
    if (!confirmed) {
      _controller.restoreFocusability();
      return;
    }
    
    confirmed = await _controller.checkUnknownRecords();
    if (!confirmed) {
      _controller.restoreFocusability();
      return;
    }

    if (!mounted) return;
    sheet(
      context: context,
      title: 'Share Bib Numbers',
      body: deviceConnectionWidget(
        context,
        DeviceConnectionService.createDevices(
          DeviceName.bibRecorder,
          DeviceType.advertiserDevice,
          data: _controller.getEncodedBibData(),
        ),
      ),
    );

    _controller.restoreFocusability();
  }

  void _resetLoadedRunners() async {
    bool confirmed = await DialogUtils.showConfirmationDialog(
      context,
      title: 'Reset Loaded Runners',
      content: 'Are you sure you want to reset all loaded runners?',
    );
    if (confirmed && mounted) {
      setState(() {
        _runners.clear();
        // Reset related bib data
        Provider.of<BibRecordsProvider>(context, listen: false).clearBibRecords();
        _checkForRunners();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Use the stored reference instead of accessing Provider in dispose
    for (var node in _providerReference.focusNodes) {
      node.removeListener(() {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Show confirmation dialog
        bool shouldPop = await DialogUtils.showConfirmationDialog(
          context,
          title: 'Leave Bib Number Screen?',
          content: 'All bib numbers will be lost if you leave this screen. Do you want to continue?',
          confirmText: 'Continue',
          cancelText: 'Stay',
        );
        return shouldPop;
      },
      child: TutorialRoot(
        tutorialManager: tutorialManager,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            body: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
              child: Column(
                children: [
                  buildRoleBar(context, 'bib recorder', tutorialManager),
                  // Stats header with bib count and runner stats
                  StatsHeaderWidget(
                    runners: _runners,
                    model: _model,
                    onReset: _resetLoadedRunners,
                  ),
                  // Bib input list section
                  Expanded(
                    child: BibListWidget(
                      scrollController: _scrollController,
                      controller: _controller,
                      tutorialManager: tutorialManager,
                    ),
                  ),
                  // Action buttons at the bottom
                  Consumer<BibRecordsProvider>(
                    builder: (context, provider, _) {
                      return provider.isKeyboardVisible 
                        ? const SizedBox.shrink() 
                        : BottomActionButtonsWidget(
                            onShareBibNumbers: _showShareBibNumbersPopup,
                          );
                    },
                  ),
                  // Keyboard accessory bar for mobile devices
                  Consumer<BibRecordsProvider>(
                    builder: (context, provider, _) {
                      if (!(Platform.isIOS || Platform.isAndroid) || !provider.isKeyboardVisible || provider.bibRecords.isEmpty) {
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
    );
  }
}
