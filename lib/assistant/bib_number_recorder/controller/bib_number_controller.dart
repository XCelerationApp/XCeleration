import 'dart:async';
import 'package:flutter/material.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/typography.dart';
import 'package:xceleration/core/utils/encode_utils.dart';
import 'package:xceleration/core/utils/enums.dart' hide RunnerRecordFlags;
import '../../../core/components/dialog_utils.dart';
import '../../../core/services/tutorial_manager.dart';
import '../../../shared/role_bar/models/role_enums.dart' as role_enums;
import '../../../shared/role_bar/role_bar.dart';
import '../../../shared/role_bar/widgets/role_selector_sheet.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../core/components/device_connection_widget.dart';
import '../../../core/services/device_connection_service.dart';
import '../../../core/utils/decode_utils.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';
import '../model/bib_record.dart';

class BibNumberController extends BibNumberDataController {
  final BuildContext context;
  late final List<BibDatum> runners;
  late final ScrollController scrollController;

  late final DevicesManager devices;

  // Debounce timer for validations
  Timer? _debounceTimer;

  BibNumberController({
    required this.context,
  }) {
    runners = [];
    scrollController = ScrollController();
    devices = DeviceConnectionService.createDevices(
      DeviceName.bibRecorder,
      DeviceType.browserDevice,
    );
    init(context);
  }

  final tutorialManager = TutorialManager();

  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// Toggles between recording and not recording states
  void toggleRecording() {
    _isRecording = !_isRecording;
    for (var node in focusNodes) {
      node.unfocus();
    }
    if (_bibRecords.isNotEmpty) {
      if (_bibRecords.last.bib.isEmpty) {
        _bibRecords.removeLast();
      }
    }
    notifyListeners();
  }

  void setupTutorials() {
    tutorialManager.startTutorial([
      // 'swipe_tutorial',
      'role_bar_tutorial',
      'add_button_tutorial'
    ]);
  }

  void init(BuildContext context) async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RoleBar.showInstructionsSheet(context, role_enums.Role.bibRecorder)
          .then((_) {
        if (context.mounted) _checkForRunners(context);
      });
    });
  }

  Future<void> _checkForRunners(BuildContext context) async {
    if (runners.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black54,
          builder: (BuildContext context) {
            return BasicAlertDialog(
              title: 'No Runners Loaded',
              content:
                  'There are no runners loaded on this phone. Please load runners to continue.',
              actions: [
                TextButton(
                  child: const Text('Switch to a Different Role',
                      style: AppTypography.buttonText),
                  onPressed: () {
                    RoleSelectorSheet.showRoleSelection(
                        context, role_enums.Role.bibRecorder,
                        showConfirmation: false);
                  },
                ),
                TextButton(
                  child: const Text('Load Runners',
                      style: AppTypography.buttonText),
                  onPressed: () async {
                    _openLoadRunnersSheet(context);
                  },
                ),
              ],
            );
          },
        );
      });
    }
  }

  /// Opens the device connection sheet directly for loading runners
  Future<void> _openLoadRunnersSheet(BuildContext context) async {
    sheet(
      context: context,
      title: 'Load Runners',
      body: deviceConnectionWidget(
        context,
        devices,
        callback: () {
          Navigator.pop(context);
          loadRunners(context);
        },
      ),
    );
  }

  Future<void> loadRunners(BuildContext context) async {
    final data = devices.coach?.data;

    if (data != null) {
      try {
        Logger.d('Data received: $data');
        // Process data outside of setState
        final loadedRunners =
            await BibDecodeUtils.decodeEncodedRunners(data, context);

        // Check if the widget is still mounted before using context
        if (!context.mounted) return;

        if (loadedRunners == null || loadedRunners.isEmpty) {
          Logger.e(
              'Invalid data received from bib recorder: $data. Please try again.',
              context: context);
          return;
        }

        Logger.d('Runners received: $loadedRunners');

        // Accept entries with only bib present; optional fields may be resolved later
        final runnerInCorrectFormat =
            loadedRunners.every((runner) => runner.isValid);

        if (!runnerInCorrectFormat) {
          Logger.e(
              'Invalid data format received from bib recorder. Please try again.',
              context: context);
          return;
        }

        if (runners.isNotEmpty) {
          runners.clear();
        }
        runners.addAll(loadedRunners);
        notifyListeners();

        Logger.d('Runners loaded: $runners');

        // Check if the widget is still mounted before using context
        if (!context.mounted) return;

        // Close dialog and handle UI updates after state is set
        if (runners.isNotEmpty) {
          // Close the "No Runners Loaded" dialog
          Navigator.of(context).pop();

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) showRunnersLoadedSheet(context);
          });

          // Setup tutorials after UI has settled
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) setupTutorials();
          });
        }
      } catch (e) {
        // Check if the widget is still mounted before showing error dialog
        if (context.mounted) {
          Logger.e('Error processing runner data: $e', context: context);
        }
      }
    } else {
      Logger.e('No data received from bib recorder. Please try again.',
          context: context);
    }
  }

  void showRunnersLoadedSheet(BuildContext context) {
    sheet(
      context: context,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Loaded Runners (${runners.length})',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  onTap: () {
                    // Close the sheet
                    Navigator.of(context).pop();
                    // Clear the runners
                    runners.clear();
                    // Reset device connection state to clear previous transfer status
                    devices.reset();
                    notifyListeners();
                    // Directly open the device connection sheet instead of showing popup
                    _openLoadRunnersSheet(context);
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh,
                          size: 16,
                          color: AppColors.primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Reload',
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: const [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Name',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Team',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Gr.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Bib',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Table Rows
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: runners.length,
              itemBuilder: (context, index) {
                final runner = runners[index];
                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            runner.name!,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            runner.teamAbbreviation!,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            runner.grade!,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            runner.bib,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> showShareBibNumbersPopup(BuildContext context) async {
    for (var node in focusNodes) {
      node.unfocus();
      // Disable focus restoration for this node
      node.canRequestFocus = false;
    }

    bool confirmed = await cleanEmptyRecords();
    if (!confirmed) {
      restoreFocusability();
      return;
    }
    if (!context.mounted) return;

    confirmed = await checkDuplicateRecords(context);
    if (!confirmed) {
      restoreFocusability();
      return;
    }
    if (!context.mounted) return;

    confirmed = await checkUnknownRecords(context);
    if (!confirmed) {
      restoreFocusability();
      return;
    }

    if (!context.mounted) return;
    final encodedData = await getEncodedBibData();
    if (!context.mounted) return;
    sheet(
      context: context,
      title: 'Share Bib Numbers',
      body: deviceConnectionWidget(
        context,
        DeviceConnectionService.createDevices(
          DeviceName.bibRecorder,
          DeviceType.advertiserDevice,
          data: encodedData,
        ),
      ),
    );

    restoreFocusability();
  }

  void resetLoadedRunners(BuildContext context) async {
    bool confirmed = await DialogUtils.showConfirmationDialog(
      context,
      title: 'Reset Loaded Runners',
      content: 'Are you sure you want to reset all loaded runners?',
    );
    if (confirmed && context.mounted) {
      runners.clear();
      notifyListeners();
      // Reset related bib data
      clearBibRecords();
      _checkForRunners(context);
    }
  }

  /// Gets a runner by bib number if it exists in the list of runners
  BibDatum? getRunnerByBib(String bib) {
    for (final runner in runners) {
      if (runner.bib == bib) {
        return runner;
      }
    }
    return null;
  }

  // Bib number validation and handling
  Future<void> validateBibNumber(int index, String bibNumber) async {
    if (index < 0 || index >= _bibRecords.length) {
      return;
    }

    // Special handling for empty inputs
    if (bibNumber.isEmpty) {
      final updatedRecord = BibDatumRecord(
        bib: bibNumber,
        name: '',
        teamAbbreviation: '',
        grade: '',
        flags: const BibDatumRecordFlags(
          notInDatabase: false,
          duplicateBibNumber: false,
        ),
      );
      updateBibRecord(index, updatedRecord);
      return;
    }

    // Try to parse the bib number
    if (!bibNumber.contains(RegExp(r'^[0-9]+$'))) {
      // Not a valid number
      final updatedRecord = BibDatumRecord(
        bib: bibNumber,
        name: '',
        teamAbbreviation: '',
        grade: '',
        flags: BibDatumRecordFlags(
          notInDatabase: true,
          duplicateBibNumber: false,
        ),
      );
      updateBibRecord(index, updatedRecord);
      return;
    }

    // Check for a matching runner
    BibDatum? matchedRunner = getRunnerByBib(bibNumber);

    if (matchedRunner != null) {
      // Found a match in database
      // Check for duplicate entries
      bool isDuplicate = false;
      int count = 0;
      for (var i = 0; i < bibRecords.length; i++) {
        if (bibRecords[i].bib == bibNumber) {
          count++;
          if (count > 1 && i == index) {
            isDuplicate = true;
            break;
          }
        }
      }

      final updatedRecord = BibDatumRecord(
        bib: bibNumber,
        name: matchedRunner.name,
        teamAbbreviation: matchedRunner.teamAbbreviation,
        grade: matchedRunner.grade,
        teamColor: matchedRunner.teamColor,
        flags: BibDatumRecordFlags(
          notInDatabase: false,
          duplicateBibNumber: isDuplicate,
        ),
      );
      updateBibRecord(index, updatedRecord);
    } else {
      // No match in database
      final updatedRecord = BibDatumRecord(
        bib: bibNumber,
        name: '',
        teamAbbreviation: '',
        grade: '',
        flags: BibDatumRecordFlags(
          notInDatabase: true,
          duplicateBibNumber: false,
        ),
      );
      updateBibRecord(index, updatedRecord);
    }
  }

  Future<void> addBib() async {
    if (bibRecords.isEmpty || bibRecords.last.bib.isNotEmpty) {
      await handleBibNumber('');
      focusNodes.last.requestFocus();
    } else {
      focusNodes.last.requestFocus();
    }
  }

  /// Handles bib number changes with optimizations to prevent UI jumping
  Future<void> handleBibNumber(
    String bibNumber, {
    int? index,
  }) async {
    // Cancel any pending debounce timer
    _debounceTimer?.cancel();

    if (index != null) {
      // Update existing record (immediately update the text but debounce validation)
      if (index < _bibRecords.length) {
        final record = _bibRecords[index];

        // Update text immediately without revalidating
        final updatedRecord = record.copyWith(bib: bibNumber);
        updateBibRecord(index, updatedRecord);

        // Debounce the validation to prevent rapid UI updates while typing
        _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
          await validateBibNumber(index, bibNumber);
        });
      }
    } else {
      // Add new record
      addBibRecord(BibDatumRecord(
        bib: bibNumber,
        name: '',
        teamAbbreviation: '',
        grade: '',
        flags: const BibDatumRecordFlags(
          notInDatabase: false,
          duplicateBibNumber: false,
        ),
      ));

      // Only scroll if necessary - check if we need to scroll to make new item visible
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToLastItemIfNeeded();
      });

      // After adding a new record, we don't need to immediately validate
      _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
        final newIndex = _bibRecords.length - 1;
        if (newIndex >= 0) {
          await validateBibNumber(newIndex, bibNumber);
        }
      });
    }

    // We don't want to revalidate all items on every keystroke
    // Only do this on explicit user actions like adding/removing items
    if (index == null) {
      // Validate all bib numbers to update duplicate states after a delay
      _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
        for (var i = 0; i < _bibRecords.length; i++) {
          if (i != index) {
            // Skip the one we're currently editing
            await validateBibNumber(i, _bibRecords[i].bib);
          }
        }
      });
    }

    if (runners.isNotEmpty && index == null) {
      // Safely determine focus index for new additions
      final focusIndex = _bibRecords.length - 1;

      // Only request focus if the index is valid
      if (focusIndex >= 0 && focusIndex < focusNodes.length) {
        // Request focus after a slight delay to allow the UI to settle
        WidgetsBinding.instance.addPostFrameCallback((_) {
          focusNodes[focusIndex].requestFocus();
        });
      }
    }
  }

  /// Only scrolls when the last item isn't already visible
  void _scrollToLastItemIfNeeded() {
    // Only attempt to scroll if we have a non-empty list and a valid scroll controller
    if (_bibRecords.isEmpty || !scrollController.hasClients) return;

    // Check if we're already near the bottom
    final position = scrollController.position;
    final viewportDimension = position.viewportDimension;
    final maxScrollExtent = position.maxScrollExtent;
    final currentOffset = position.pixels;

    // If we're not already seeing the bottom part of the list, scroll to make new item visible
    if (maxScrollExtent > 0 &&
        (maxScrollExtent - currentOffset) > (viewportDimension / 2)) {
      scrollController.animateTo(
        maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  @override
  void dispose() {
    // Cancel timer first before any other cleanup
    _debounceTimer?.cancel();

    // Dispose of tutorial manager
    tutorialManager.dispose();

    // Dispose of scroll controller
    if (scrollController.hasClients) {
      scrollController.dispose();
    }
    super.dispose();
  }
}

class BibNumberDataController extends ChangeNotifier {
  final List<BibDatumRecord> _bibRecords = [];
  final List<TextEditingController> controllers = [];
  final List<FocusNode> focusNodes = [];

  bool _isKeyboardVisible = false;

  bool get isKeyboardVisible => _isKeyboardVisible;

  set isKeyboardVisible(bool visible) {
    _isKeyboardVisible = visible;
    notifyListeners();
  }

  List<BibDatumRecord> get bibRecords => _bibRecords;

  bool get canAddBib {
    if (_bibRecords.isEmpty) return true;
    final BibDatumRecord lastBib = _bibRecords.last;
    // Only prevent adding if the last bib is completely empty AND has focus
    // If the last bib has content (even if runner not found), allow adding
    if (lastBib.bib.isEmpty && focusNodes.last.hasPrimaryFocus) return false;
    return true;
  }

  // Synchronizes collections to match bibRecords length
  void _syncCollections() {
    // If collections are out of sync, reset them
    if (!(_bibRecords.length == controllers.length &&
        controllers.length == focusNodes.length)) {
      // Save existing bib records
      final existingRecords = List<BibDatumRecord>.from(_bibRecords);

      // Clear and dispose all existing controllers and focus nodes
      for (var controller in controllers) {
        if (controller.hasListeners) {
          controller.dispose();
        }
      }
      controllers.clear();

      for (var node in focusNodes) {
        node.dispose();
      }
      focusNodes.clear();

      // Reset records collection
      _bibRecords.clear();

      // Re-add all records with fresh controllers and focus nodes
      for (var record in existingRecords) {
        addBibRecord(record);
      }
    }
  }

  /// Adds a new bib record with the specified runner record.
  /// Returns the index of the added record.
  int addBibRecord(BibDatumRecord record) {
    _bibRecords.add(record);

    final newIndex = _bibRecords.length - 1;
    final controller = TextEditingController(text: record.bib);
    controllers.add(controller);

    final focusNode = FocusNode();
    focusNode.addListener(() {
      if (focusNode.hasFocus != _isKeyboardVisible) {
        _isKeyboardVisible = focusNode.hasFocus;
        notifyListeners();
      }
    });
    focusNodes.add(focusNode);

    notifyListeners();

    return newIndex;
  }

  /// Updates an existing bib record at the specified index.
  void updateBibRecord(int index, BibDatumRecord record) {
    if (index < 0 || index >= _bibRecords.length) return;

    // Ensure collections are in sync
    _syncCollections();

    _bibRecords[index] = record;

    // Only update the controller text if it differs to avoid cursor jumping
    if (index < controllers.length) {
      final currentText = controllers[index].text;
      if (currentText != record.bib) {
        controllers[index].text = record.bib;
      }
    }

    notifyListeners();
  }

  /// Removes a bib record at the specified index.
  void removeBibRecord(int index) {
    if (index < 0 || index >= _bibRecords.length) return;

    // Ensure collections are in sync before removing
    _syncCollections();

    if (index >= controllers.length || index >= focusNodes.length) return;

    _bibRecords.removeAt(index);

    // Clean up resources
    controllers[index].dispose();
    controllers.removeAt(index);

    focusNodes[index].dispose();
    focusNodes.removeAt(index);

    notifyListeners();
  }

  void clearBibRecords() {
    _bibRecords.clear();

    // Dispose all controllers and focus nodes
    for (var controller in controllers) {
      controller.dispose();
    }
    controllers.clear();

    for (var node in focusNodes) {
      node.dispose();
    }
    focusNodes.clear();

    notifyListeners();
  }

  /// Restores the focus abilities for all focus nodes
  void restoreFocusability() {
    for (var node in focusNodes) {
      node.canRequestFocus = true;
    }
  }

  /// Gets the encoded bib data for sharing
  Future<String> getEncodedBibData() async {
    return await BibEncodeUtils.getEncodedBibData(_bibRecords);
  }

  /// Returns all unique bib numbers and the corresponding runner records
  Map<String, BibDatumRecord> getBibsAndRunners() {
    final map = <String, BibDatumRecord>{};
    for (final record in _bibRecords) {
      if (record.bib.isNotEmpty) {
        map[record.bib] = record;
      }
    }
    return map;
  }

  Future<bool> checkDuplicateRecords(BuildContext context) async {
    final records = _bibRecords;

    // Find all duplicate bib numbers
    final duplicates = <String>{};
    final seen = <String>{};

    for (final record in records) {
      final bib = record.bib;
      if (bib.isEmpty) continue;

      if (seen.contains(bib)) {
        duplicates.add(bib);
      } else {
        seen.add(bib);
      }
    }

    if (duplicates.isEmpty) {
      return true;
    }

    return await DialogUtils.showConfirmationDialog(
      context,
      title: 'Duplicate Bib Numbers',
      content:
          'There are duplicate bib numbers in the list: ${duplicates.join(', ')}. Do you want to continue?',
    );
  }

  Future<bool> checkUnknownRecords(BuildContext context) async {
    final records = _bibRecords;

    bool hasUnknown = false;
    for (final record in records) {
      if (record.flags.notInDatabase) {
        hasUnknown = true;
        break;
      }
    }

    if (!hasUnknown) {
      return true;
    }

    return await DialogUtils.showConfirmationDialog(
      context,
      title: 'Unknown Bib Numbers',
      content:
          'There are bib numbers in the list that do not match any runners in the database. Do you want to continue?',
    );
  }

  Future<bool> cleanEmptyRecords() async {
    final emptyRecords = _bibRecords.where((bib) => bib.bib.isEmpty).toList();

    for (var i = emptyRecords.length - 1; i >= 0; i--) {
      final index = _bibRecords.indexOf(emptyRecords[i]);
      if (index >= 0) {
        removeBibRecord(index);
      }
    }
    return true;
  }

  // Helper to check if we have any non-empty bib numbers
  bool hasNonEmptyBibNumbers() {
    return _bibRecords.any((record) => record.bib.isNotEmpty);
  }

  // Helper to count non-empty bib numbers
  int countNonEmptyBibNumbers() {
    return _bibRecords.where((bib) => bib.bib.isNotEmpty).length;
  }

  // Helper to count empty bib numbers
  int countEmptyBibNumbers() {
    return _bibRecords.where((bib) => bib.bib.isEmpty).length;
  }

  // Helper to count duplicate bib numbers
  int countDuplicateBibNumbers() {
    return _bibRecords
        .where((bib) => bib.flags.duplicateBibNumber == true)
        .length;
  }

  // Helper to count unknown bib numbers
  int countUnknownBibNumbers() {
    return _bibRecords.where((bib) => bib.flags.notInDatabase == true).length;
  }

  @override
  void dispose() {
    // Dispose of focus nodes
    for (var node in focusNodes) {
      try {
        // Try to remove listeners first to prevent callbacks during dispose
        node.removeListener(() {});
        node.dispose();
      } catch (e) {
        // Node may already be disposed, ignore the error
        Logger.d('Warning: Error disposing focus node: $e');
      }
    }

    // Dispose of text controllers
    for (var controller in controllers) {
      try {
        controller.dispose();
      } catch (e) {
        // Controller may already be disposed, ignore the error
        Logger.d('Warning: Error disposing text controller: $e');
      }
    }

    // Clear collections but don't notify listeners since we're disposing
    _bibRecords.clear();
    controllers.clear();
    focusNodes.clear();
    super.dispose();
  }
}
