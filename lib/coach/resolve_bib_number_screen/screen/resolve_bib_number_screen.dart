import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/components/button_components.dart';
import '../../../core/components/dialog_utils.dart';
import 'package:xceleration/core/components/textfield_utils.dart';
import '../controller/resolve_bib_number_controller.dart';
import '../widgets/search_results.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/components/runner_input_form.dart';
import 'package:xceleration/core/utils/color_utils.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';

class ResolveBibNumberScreen extends StatefulWidget {
  final List<RaceRunner> raceRunners;
  final int raceId;
  final RaceRunner raceRunner;
  final Function(RaceRunner) onComplete;
  final Future<void> Function(RaceRunner) onAssignOriginalRaceRunner;

  const ResolveBibNumberScreen({
    super.key,
    required this.raceRunners,
    required this.raceId,
    required this.raceRunner,
    required this.onComplete,
    required this.onAssignOriginalRaceRunner,
  });

  @override
  State<ResolveBibNumberScreen> createState() => _ResolveBibNumberScreenState();
}

class _ResolveBibNumberScreenState extends State<ResolveBibNumberScreen> {
  late ResolveBibNumberController _controller;
  bool _isUnknownConflict = true;

  @override
  void initState() {
    super.initState();
    _controller = ResolveBibNumberController(
      raceRunners: widget.raceRunners,
      raceId: widget.raceId,
      onComplete: widget.onComplete,
      raceRunner: widget.raceRunner,
    );
    _controller.loadTeams();

    // Detect conflict type and set up form accordingly
    _setupFormForConflictType();

    // Ensure "Choose Existing Runner" is selected by default
    _controller.showCreateNew = false;
    // Initialize search with empty query to load all available runners
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.searchRunners('');
    });
  }

  void _setupFormForConflictType() {
    // Check if this is an unknown bib conflict (bib set, other fields empty)
    // or duplicate bib conflict (all fields populated)
    _isUnknownConflict = widget.raceRunner.runner.name == null ||
        widget.raceRunner.runner.name!.isEmpty ||
        widget.raceRunner.runner.grade == null ||
        widget.raceRunner.team.name == null ||
        widget.raceRunner.team.name!.isEmpty;

    if (_isUnknownConflict) {
      // For unknown conflicts, prefill the bib number
      _controller.bibController.text = widget.raceRunner.runner.bibNumber ?? '';
    } else {
      // For duplicate conflicts, leave bib number empty so user can choose new one
      _controller.bibController.text = '';
    }

    // Always leave name, grade, and team fields empty for manual entry
    // Only the bib field differs between conflict types
    _controller.nameController.text = '';
    _controller.gradeController.text = '';
    _controller.teamController.text = '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit(RaceRunner raceRunner) async {
    final name = raceRunner.runner.name;
    final grade = raceRunner.runner.grade;
    final teamName = raceRunner.team.name;
    final bib = raceRunner.runner.bibNumber;

    if (name == null || grade == null || teamName == null || bib == null) {
      if (mounted) {
        DialogUtils.showErrorDialog(
          context,
          message: 'Runner is missing required fields (name, grade, team, or bib number).',
        );
      }
      return;
    }

    // Transfer form data to controller for resolution
    _controller.nameController.text = name;
    _controller.gradeController.text = grade.toString();
    _controller.teamController.text = teamName;
    _controller.bibController.text = bib;

    final error = await _controller.createNewRunner();
    if (error != null && mounted) {
      DialogUtils.showErrorDialog(context, message: error.userMessage);
    }
  }

  Widget _buildCreateNewForm(ResolveBibNumberController controller) {
    if (controller.isLoadingTeams) {
      return const Expanded(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Expanded(
      child: SingleChildScrollView(
        child: RunnerInputForm(
          raceId: widget.raceId,
          initialRaceRunner: controller.raceRunner,
          teamOptions: controller.teamsList,
          onSubmit: _handleSubmit,
          getRunnerByBib: controller.masterRace.getRunnerByBib,
          submitButtonText: 'Create New Runner',
          useSheetLayout: false,
          showBibField: true,
          bibController: controller.bibController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color:
                          ColorUtils.withOpacity(AppColors.primaryColor, 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: ColorUtils.withOpacity(
                                AppColors.primaryColor, 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.warning_rounded,
                            color: AppColors.primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isUnknownConflict
                                    ? 'Unrecognized Bib Number'
                                    : 'Duplicate Bib Number',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isUnknownConflict
                                    ? 'We could not identify this runner with bib number ${_controller.raceRunner.runner.bibNumber}.\nPlease choose an existing runner or create a new one.'
                                    : 'This bib number is already assigned to another runner.\nPlease choose an existing runner or create a new one.',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                ActionButton(
                  onPressed: () async {
                    await widget.onAssignOriginalRaceRunner(widget.raceRunner);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  text: 'This is the original runner',
                  isPrimary: false,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Flexible(
                      flex: 1,
                      child: SharedActionButton(
                        text: 'Choose Existing Runner',
                        icon: Icons.person_search,
                        isPrimary: !_controller.showCreateNew,
                        onPressed: () {
                          _controller.setShowCreateNew(false);
                          _controller.searchRunners(
                              _controller.searchController.text);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      flex: 1,
                      child: SharedActionButton(
                        text: 'Create New Runner',
                        icon: Icons.person_add,
                        isPrimary: _controller.showCreateNew,
                        onPressed: () {
                          _controller.setShowCreateNew(true);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Consumer<ResolveBibNumberController>(
                  builder: (context, controller, _) {
                    return !controller.showCreateNew
                        ? Expanded(
                            child: Column(
                              children: [
                                buildTextField(
                                  context: context,
                                  controller: controller.searchController,
                                  hint: 'Search runners',
                                  onChanged: (value) =>
                                      controller.searchRunners(value),
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: SearchResults(
                                    controller: controller,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _buildCreateNewForm(controller);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
