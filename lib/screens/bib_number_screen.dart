import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
// import '../models/race.dart';
import '../models/bib_data.dart';
import '../utils/app_colors.dart';
import '../utils/dialog_utils.dart';
import '../utils/button_utils.dart';
// import '../utils/time_formatter.dart';
import '../utils/device_connection_widget.dart';
import '../utils/device_connection_service.dart';
// import '../database_helper.dart';
// import '../runner_time_functions.dart';
// import 'race_screen.dart';
import '../role_functions.dart';
import 'dart:io';
import '../utils/tutorial_manager.dart';
import '../utils/coach_mark.dart';
import '../utils/typography.dart';
import '../utils/enums.dart';
import '../utils/sheet_utils.dart';

class BibNumberScreen extends StatefulWidget {
  // final Race? race;
  const BibNumberScreen({super.key});

  @override
  State<BibNumberScreen> createState() => _BibNumberScreenState();
}

class _BibNumberScreenState extends State<BibNumberScreen> {
  // late Race race;
  // List<dynamic> _runners = [{'bib_number': '1234', 'name': 'Teo Donnelley', 'school': 'AW', 'grade': '11'}];
  List<dynamic> _runners = [];
  Map<DeviceName, Map<String, dynamic>> otherDevices = createOtherDeviceList(
    DeviceName.bibRecorder,
    DeviceType.browserDevice,
  );

  final ScrollController _scrollController = ScrollController();

  final tutorialManager = TutorialManager();

  @override
  void initState() {
    super.initState();
    _checkForRunners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _setupTutorials();
    });
  }


  void _setupTutorials() {
    tutorialManager.startTutorial([
      // 'swipe_tutorial',
      'role_bar_tutorial',
      'add_button_tutorial'
    ]);
  }

  Future<void> _checkForRunners() async{
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
                  onPressed: () async{
                    sheet(
                      context: context,
                      title: 'Load Runners',
                      body: deviceConnectionWidget(
                        DeviceName.coach,
                        DeviceType.browserDevice,
                        createOtherDeviceList(
                          DeviceName.coach,
                          DeviceType.browserDevice,
                        ),
                      ),
                    );
                    await waitForDataTransferCompletion(otherDevices);
                    setState(() {
                      final data = otherDevices[DeviceName.coach]?['data'];
                      if (data != null) {
                        final runners = jsonDecode(data);
                        if (runners.runtimeType != List || runners.isEmpty) {
                          DialogUtils.showErrorDialog(context, 
                            message: 'Invalid data received from bib recorder. Please try again.');
                        }
                        final runnerInCorrectFormat = runners.every((runner) => runner.containsKey('bib_number') && runner.containsKey('name') && runner.containsKey('school') && runner.containsKey('grade'));
                        if (!runnerInCorrectFormat) {
                          DialogUtils.showErrorDialog(context, 
                            message: 'Invalid data received from bib recorder. Please try again.');
                        }

                        if (_runners.isNotEmpty) _runners.clear();
                        debugPrint('Runners loaded: $runners');
                        _runners = runners;
                      }
                    });
                    if (_runners.isNotEmpty && context.mounted) {
                      Navigator.pop(context);  
                      _handleBibNumber('');
                    }
                    else {
                      debugPrint('No runners loaded');
                    }
                  },
                ),
              ],
            );
          },
        );
      });
    }
  }

  List<Map<String, dynamic>> decodeRunners(String encodedRunners) {
    List<Map<String, dynamic>> runners = [];
    for (var runner in encodedRunners.split(' ')) {
      if (runner.isNotEmpty) {
        List<String> runnerValues = runner.split(',');
        if (runnerValues.length == 4) {
          runners.add({
            'bib_number': runnerValues[0],
            'name': runnerValues[1],
            'school': runnerValues[2],
            'grade': runnerValues[3],
          });
        }
      }
    }
    return runners;
  }

  Future<void> _validateBibNumber(int index, String bibNumber, List<double>? confidences) async {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    final record = provider.bibRecords[index];

    // Reset all flags first
    record.flags['low_confidence_score'] = false;
    record.flags['not_in_database'] = false;
    record.flags['duplicate_bib_number'] = false;
    record.name = '';
    record.school = '';

    // If bibNumber is empty, clear all flags and return
    if (bibNumber.isEmpty) {
      setState(() {});
      return;
    }

    // Check confidence scores
    if (confidences?.any((score) => score < 0.9) ?? false) {
      record.flags['low_confidence_score'] = true;
    }

    // Check database
    final runner = getRunnerByBib(bibNumber);
    if (runner == null) {
      record.flags['not_in_database'] = true;
    } else {
      record.name = runner['name'];
      record.school = runner['school'];
      record.flags['not_in_database'] = false;
    }

    // Check duplicates
    final duplicateIndexes = provider.bibRecords
        .asMap()
        .entries
        .where((e) => e.value.bibNumber == bibNumber && e.value.bibNumber.isNotEmpty)
        .map((e) => e.key)
        .toList();

    if (duplicateIndexes.length > 1) {
      // Mark as duplicate if this is not the first occurrence
      record.flags['duplicate_bib_number'] = duplicateIndexes.indexOf(index) > 0;
    }

    setState(() {});
  }

  void _onBibRecordRemoved(int index) {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    provider.removeBibRecord(index);

    // Revalidate all remaining bib numbers to update duplicate flags
    for (var i = 0; i < provider.bibRecords.length; i++) {
      _validateBibNumber(i, provider.bibRecords[i].bibNumber, null);
    }
  }

  // UI Components
  Widget _buildBibInput(int index, BibRecord record) {
    return GestureDetector(
      onTap: () {
        final provider = Provider.of<BibRecordsProvider>(context, listen: false);
        provider.focusNodes[index].requestFocus();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 60,
              child: _buildBibTextField(index, Provider.of<BibRecordsProvider>(context)),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (record.name.isNotEmpty && !record.hasErrors)
                    _buildRunnerInfo(record)
                  else if (record.hasErrors)
                    _buildErrorText(record),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBibTextField(int index, BibRecordsProvider provider) {
    return TextField(
      focusNode: provider.focusNodes[index],
      controller: provider.controllers[index],
      keyboardType: TextInputType.number,
      style: AppTypography.bodyRegular,
      textAlign: TextAlign.start,
      decoration: InputDecoration(
        labelText: 'Bib #',
        labelStyle: AppTypography.bodyRegular,
        border: const OutlineInputBorder(),
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      onSubmitted: (_) async {
        await _handleBibNumber('');
      },
      onChanged: (value) => _handleBibNumber(value, index: index),
      keyboardAppearance: Brightness.light,
    );
  }

  Widget _buildRunnerInfo(BibRecord record) {
    if (record.flags['not_in_database'] == false && record.bibNumber.isNotEmpty) {
      return Text(
        '${record.name}, ${record.school}',
        textAlign: TextAlign.center,
        style: AppTypography.bodyRegular,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildErrorText(BibRecord record) {
    final errors = <String>[];
    if (record.flags['duplicate_bib_number']!) errors.add('Duplicate Bib Number');
    if (record.flags['not_in_database']!) errors.add('Runner not found');
    if (record.flags['low_confidence_score']!) errors.add('Low Confidence Score');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 16, color: Colors.red),
        const SizedBox(width: 8),
        Text(
          errors.join(' • '),
          style: AppTypography.bodyRegular.copyWith(
            color: Colors.red,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: CoachMark(
          id: 'add_button_tutorial',
          tutorialManager: tutorialManager,
          config: const CoachMarkConfig(
            title: 'Add Runner',
            alignmentX: AlignmentX.center,
            alignmentY: AlignmentY.bottom,
            description: 'Click here to add a new runner',
            icon: Icons.add_circle_outline,
            type: CoachMarkType.targeted,
            backgroundColor: Color(0xFF1976D2),
            elevation: 12,
          ),
          child: InkWell(
            onTap: () => _handleBibNumber(''),
            borderRadius: BorderRadius.circular(35),
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.add_circle_outline,
                size: 40,
                color: AppColors.primaryColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionButtons() {
    final bibRecordsProvider = Provider.of<BibRecordsProvider>(context, listen: false);
    final hasNonEmptyBibNumbers = bibRecordsProvider.bibRecords.any((record) => record.bibNumber.isNotEmpty);

    if (!hasNonEmptyBibNumbers) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: RoundedRectangleButton(
        text: 'Share Bib Numbers',
        color: AppColors.navBarColor,
        width: double.infinity,
        height: 50,
        fontSize: 18,
        onPressed: _showShareBibNumbersPopup,
      ),
    );
  }

  String _getEncodedBibData() {
    final bibRecordsProvider = Provider.of<BibRecordsProvider>(context, listen: false);
    return bibRecordsProvider.bibRecords.map((record) => record.bibNumber).toList().join(' ');
  }

  void _showShareBibNumbersPopup() async {
    // Clear all focus nodes to prevent focus restoration
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    for (var node in provider.focusNodes) {
      node.unfocus();
      // Disable focus restoration for this node
      node.canRequestFocus = false;
    }

    bool confirmed = await _cleanEmptyRecords();
    if (!confirmed) {
      _restoreFocusability();
      return;
    }
    
    confirmed = await _checkDuplicateRecords();
    if (!confirmed) {
      _restoreFocusability();
      return;
    }
    
    confirmed = await _checkUnknownRecords();
    if (!confirmed) {
      _restoreFocusability();
      return;
    }

    final String bibData = _getEncodedBibData();
    if (!mounted) return;
    sheet(
      context: context,
      title: 'Share Bib Numbers',
      body: deviceConnectionWidget(
        DeviceName.bibRecorder,
        DeviceType.advertiserDevice,
        createOtherDeviceList(
          DeviceName.bibRecorder,
          DeviceType.advertiserDevice,
          data: bibData,
        ),
      ),
    );

  _restoreFocusability();
  }

  void _restoreFocusability() {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    for (var node in provider.focusNodes) {
      node.canRequestFocus = true;
    }
  }

  Future<bool> _cleanEmptyRecords() async {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    final emptyRecords = provider.bibRecords.where((bib) => bib.bibNumber.isEmpty).length;
    
    if (emptyRecords > 0) {
      final confirmed = await DialogUtils.showConfirmationDialog(
        context,
        title: 'Clean Empty Records',
        content: 'There are $emptyRecords empty bib numbers that will be deleted. Continue?',
      );
      
      if (confirmed) {
        setState(() {
          provider.bibRecords.removeWhere((bib) => bib.bibNumber.isEmpty);
        });
      }
      return confirmed;
    }
    return true;
  }

  Future<bool> _checkDuplicateRecords() async {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    final duplicateRecords = provider.bibRecords.where((bib) => bib.flags['duplicate_bib_number'] == true).length;
    
    if (duplicateRecords > 0) {
      final confirmed = await DialogUtils.showConfirmationDialog(
        context,
        title: 'Duplicate Bib Numbers',
        content: 'There are $duplicateRecords duplicate bib numbers. Do you want to continue?',
      );
      return confirmed;
    }
    return true;
  }

  Future<bool> _checkUnknownRecords() async {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    final unknownRecords = provider.bibRecords.where((bib) => bib.flags['not_in_database'] == true).length;
    
    if (unknownRecords > 0) {
      final confirmed = await DialogUtils.showConfirmationDialog(
        context,
        title: 'Unknown Bib Numbers',
        content: 'There are $unknownRecords bib numbers that are not in the database. Do you want to continue?',
      );
      return confirmed;
    }
    return true;
  }

  Future<void> _handleBibNumber(String bibNumber, {
    List<double>? confidences,
    int? index,
  }) async {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    
    if (index != null) {
      _validateBibNumber(index, bibNumber, confidences);
      provider.updateBibRecord(index, bibNumber);
    } else {
      provider.addBibRecord(BibRecord(
        bibNumber: bibNumber,
        confidences: confidences ?? [],
      ));
      // Scroll to bottom when adding new bib
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    // Validate all bib numbers to update duplicate states
    for (var i = 0; i < provider.bibRecords.length; i++) {
      await _validateBibNumber(i, provider.bibRecords[i].bibNumber, 
        i == index ? confidences : null);
    }

    if (_runners.isNotEmpty && mounted) {
      Provider.of<BibRecordsProvider>(context, listen: false)
        .focusNodes[index ?? provider.bibRecords.length - 1]
        .requestFocus();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  dynamic getRunnerByBib(String bibNumber) {
    try {
      return _runners.firstWhere(
        (runner) => runner['bib_number'] == bibNumber,
        orElse: () => null,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    for (var node in provider.focusNodes) {
      node.removeListener(() {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TutorialRoot(
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
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Consumer<BibRecordsProvider>(
                    builder: (context, provider, _) {
                      return Text(
                        'Bib Number Count: ${provider.bibRecords.where((bib) => bib.bibNumber.isNotEmpty).length}',
                        style: AppTypography.bodyRegular
                      );
                    }
                  )
                ),
                Expanded(
                  child: Consumer<BibRecordsProvider>(
                    builder: (context, provider, child) {
                      return ListView.builder(
                        controller: _scrollController,
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
                                  // Disable focus restoration for this node
                                  node.canRequestFocus = false;
                                }
                                bool delete = await DialogUtils.showConfirmationDialog(
                                  context,
                                  title: 'Confirm Deletion',
                                  content: 'Are you sure you want to delete this bib number?',
                                );
                                _restoreFocusability();
                                return delete;
                              },
                              onDismissed: (direction) {
                                setState(() {
                                  _onBibRecordRemoved(index);
                                });
                              },
                              child: _buildBibInput(
                                index,
                                provider.bibRecords[index],
                              ),
                            );
                          }
                          return _buildAddButton();
                        },
                      );
                    },
                  ),
                ),
                Consumer<BibRecordsProvider>(
                  builder: (context, provider, _) {
                    return provider.isKeyboardVisible 
                      ? const SizedBox.shrink() 
                      : _buildBottomActionButtons();
                  },
                ),
                Consumer<BibRecordsProvider>(
                  builder: (context, provider, _) {
                    if (!(Platform.isIOS || Platform.isAndroid) ||!provider.isKeyboardVisible || provider.bibRecords.isEmpty) return const SizedBox.shrink();
                    return Container(
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD2D5DB), // iOS numeric keypad color
                        border: Border(
                          top: BorderSide(
                            color: Color(0xFFBBBBBB),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 16.0),
                            child: TextButton(
                              onPressed: () => FocusScope.of(context).unfocus(),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                overlayColor: Color.fromARGB(255, 78, 78, 80),
                              ),
                              child: Text(
                                'Done',
                                style: AppTypography.bodyRegular.copyWith(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.darkColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      )
    );
  }
}
