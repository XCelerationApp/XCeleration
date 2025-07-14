import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/components/button_components.dart';
import 'package:xceleration/core/components/textfield_utils.dart';
import '../controller/resolve_bib_number_controller.dart';
import '../widgets/search_results.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/components/runner_input_form.dart';
import 'package:xceleration/core/utils/color_utils.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

class ResolveBibNumberScreen extends StatefulWidget {
  final List<RaceRunner> raceRunners;
  final int raceId;
  final RaceRunner raceRunner;
  final Function(RaceRunner) onComplete;

  const ResolveBibNumberScreen({
    super.key,
    required this.raceRunners,
    required this.raceId,
    required this.raceRunner,
    required this.onComplete,
  });

  @override
  State<ResolveBibNumberScreen> createState() => _ResolveBibNumberScreenState();
}

class _ResolveBibNumberScreenState extends State<ResolveBibNumberScreen> {
  late ResolveBibNumberController _controller;
  List<Team> _teams = [];
  bool _isLoadingTeams = true;

  @override
  void initState() {
    super.initState();
    _controller = ResolveBibNumberController(
      raceRunners: widget.raceRunners,
      raceId: widget.raceId,
      onComplete: widget.onComplete,
      raceRunner: widget.raceRunner,
    );
    _controller.setContext(context);
    _loadTeams();
    // Ensure "Choose Existing Runner" is selected by default
    _controller.showCreateNew = false;
    // Initialize search with empty query to load all available runners
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.searchRunners('');
    });
  }

  @override
  void dispose() {
    // Controller will be disposed through the Provider
    super.dispose();
  }

  Future<void> _loadTeams() async {
    try {
      // Load teams using the controller's teams getter (from MasterRace)
      final teams = await _controller.teams;

      // Check if widget is still mounted before calling setState
      if (!mounted) return;

      setState(() {
        _teams = teams;
        _isLoadingTeams = false;
      });
    } catch (e) {
      // Check if widget is still mounted before calling setState
      if (!mounted) return;

      setState(() {
        _teams = [];
        _isLoadingTeams = false;
      });
    }
  }

  Future<void> _handleSubmit(RaceRunner raceRunner) async {
    // Transfer form data to controller for resolution
    _controller.nameController.text = raceRunner.runner.name!;
    _controller.gradeController.text = raceRunner.runner.grade!.toString();
    _controller.teamController.text = raceRunner.team.name!;

    // Now call the controller's method to create the runner
    await _controller.createNewRunner();
  }

  Widget _buildCreateNewForm() {
    if (_isLoadingTeams) {
      return const Expanded(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Expanded(
      child: SingleChildScrollView(
        child: RunnerInputForm(
          initialRaceRunner: _controller.raceRunner,
          teamOptions: _teams,
          masterRace: _controller.masterRace,
          onSubmit: _handleSubmit,
          // No team creation allowed when resolving bib conflicts
          onTeamCreated: null,
          submitButtonText: 'Create New Runner',
          useSheetLayout: false,
          showBibField: false,
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
                              const Text(
                                'Unrecognized Bib Number',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'We could not identify this runner with bib number ${_controller.raceRunner.runner.bibNumber}.\nPlease choose an existing runner or create a new one.',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Flexible(
                      flex: 1,
                      child: SharedActionButton(
                        text: 'Choose Existing Runner',
                        icon: Icons.person_search,
                        isSelected: !_controller.showCreateNew,
                        onPressed: () {
                          setState(() {
                            _controller.showCreateNew = false;
                            _controller.searchRunners(
                                _controller.searchController.text);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      flex: 1,
                      child: SharedActionButton(
                        text: 'Create New Runner',
                        icon: Icons.person_add,
                        isSelected: _controller.showCreateNew,
                        onPressed: () {
                          setState(() {
                            _controller.showCreateNew = true;
                          });
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
                                  setSheetState: setState,
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
                        : _buildCreateNewForm();
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
