import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/sheet_utils.dart';
import '../utils/logger.dart';
import './textfield_utils.dart' as textfield_utils;
import '../components/button_components.dart';
import '../../shared/models/database/team.dart';
import '../../shared/models/database/race_runner.dart';
import '../../shared/models/database/runner.dart';
import 'create_team_sheet.dart';
import '../../shared/models/database/master_race.dart';

/// A shared widget for runner input form used across the app
class RunnerInputForm extends StatefulWidget {
  /// Race ID associated with this runner
  final MasterRace masterRace;

  /// List of available team names
  final List<Team> teamOptions;

  /// Callback when the form is submitted
  final Future<void> Function(RaceRunner) onSubmit;

  /// Initial runner data (for editing)
  final RaceRunner? initialRaceRunner;

  /// Required team data (for creating a new runner with a specific team)
  final Team? requiredTeam;

  /// Button text for the submit button
  final String submitButtonText;

  /// Whether to show the form in a sheet layout (with labels on left)
  final bool useSheetLayout;

  /// Whether to show the bib field
  final bool showBibField;

  /// Callback when a new team is created
  final Future<void> Function(Team)? onTeamCreated;

  const RunnerInputForm({
    super.key,
    required this.masterRace,
    required this.teamOptions,
    required this.onSubmit,
    this.initialRaceRunner,
    this.requiredTeam,
    this.submitButtonText = 'Create',
    this.useSheetLayout = true,
    this.showBibField = true,
    this.onTeamCreated,
  });

  @override
  State<RunnerInputForm> createState() => _RunnerInputFormState();
}

class _RunnerInputFormState extends State<RunnerInputForm> {
  // Internal controllers that will be managed by this widget
  late TextEditingController nameController;
  late TextEditingController gradeController;
  late TextEditingController teamController;
  late TextEditingController teamAbbreviationController;
  late TextEditingController bibController;

  String? nameError;
  String? gradeError;
  String? teamError;
  String? teamAbbreviationError;
  String? bibError;

  // Track updated team options including newly created teams
  late List<Team> _currentTeamOptions;

  // Track the currently selected team
  Team? _selectedTeam;

  // Track the team that needs to be created when form is submitted
  Team? _pendingTeamCreation;

  @override
  void initState() {
    super.initState();

    // Initialize controllers
    nameController = TextEditingController();
    gradeController = TextEditingController();
    teamController = TextEditingController();
    teamAbbreviationController = TextEditingController();
    bibController = TextEditingController();

    // Initialize team options
    _currentTeamOptions = List.from(widget.teamOptions);

    // Initialize with existing data if editing
    if (widget.initialRaceRunner != null) {
      nameController.text = widget.initialRaceRunner!.runner.name!;
      gradeController.text = widget.initialRaceRunner!.runner.grade!.toString();
      teamController.text = widget.initialRaceRunner!.team.name!;
      bibController.text = widget.initialRaceRunner!.runner.bibNumber!;
      _selectedTeam = widget.initialRaceRunner!.team;
      teamAbbreviationController.text =
          widget.initialRaceRunner!.team.abbreviation ?? '';
    }
    if (widget.requiredTeam != null) {
      teamController.text = widget.requiredTeam!.name!;
      _selectedTeam = widget.requiredTeam!;
      teamAbbreviationController.text = widget.requiredTeam!.abbreviation ?? '';
    }
  }

  @override
  void dispose() {
    // Clean up controllers when the widget is disposed
    nameController.dispose();
    gradeController.dispose();
    teamController.dispose();
    teamAbbreviationController.dispose();
    bibController.dispose();
    super.dispose();
  }

  void validateName(String value) {
    if (value.isEmpty) {
      setState(() {
        nameError = 'Please enter a name';
      });
    } else {
      setState(() {
        nameError = null;
      });
    }
  }

  void validateGrade(String value) {
    if (value.isEmpty) {
      setState(() {
        gradeError = 'Please enter a grade';
      });
    } else if (int.tryParse(value) == null) {
      setState(() {
        gradeError = 'Please enter a valid grade number';
      });
    } else {
      final grade = int.parse(value);
      if (grade < 9 || grade > 12) {
        setState(() {
          gradeError = 'Grade must be between 9 and 12';
        });
      } else {
        setState(() {
          gradeError = null;
        });
      }
    }
  }

  void validateTeam(Team? value) {
    if (value == null) {
      setState(() {
        teamError = 'Please select a team';
      });
    } else if (value.name == null || value.name!.isEmpty) {
      setState(() {
        teamError = 'Please enter a team name';
      });
    } else if (value.color == null) {
      setState(() {
        teamError = 'Please enter a team color';
      });
    } else {
      setState(() {
        teamError = null;
      });
    }
  }

  void validateTeamAbbreviation(String value) {
    if (value.isEmpty) {
      setState(() {
        teamAbbreviationError = 'Please enter a team abbreviation';
      });
    } else if (value.length > 3) {
      setState(() {
        teamAbbreviationError =
            'Team abbreviation must be 3 characters or less';
      });
    } else {
      setState(() {
        teamAbbreviationError = null;
      });
    }
  }

  void validateBib(String value) {
    if (value.isEmpty) {
      setState(() {
        bibError = 'Please enter a bib number';
      });
    } else if (int.tryParse(value) == null) {
      setState(() {
        bibError = 'Please enter a valid bib number';
      });
    } else if (int.parse(value) <= 0) {
      setState(() {
        bibError = 'Please enter a bib number greater than 0';
      });
    } else {
      setState(() {
        bibError = null;
      });
    }
  }

  bool hasErrors() {
    return teamError != null ||
        bibError != null ||
        gradeError != null ||
        nameError != null ||
        nameController.text.isEmpty ||
        gradeController.text.isEmpty ||
        teamController.text.isEmpty ||
        bibController.text.isEmpty;
  }

  Future<void> handleSubmit() async {
    if (hasErrors()) {
      return;
    }

    try {
      // Create any pending team before submitting the runner
      if (_pendingTeamCreation != null && widget.onTeamCreated != null) {
        await widget.onTeamCreated!(_pendingTeamCreation!);
      }

      final runner = RaceRunner(
        raceId: widget.masterRace.raceId,
        runner: Runner(
          name: nameController.text,
          grade: int.tryParse(gradeController.text) ?? 0,
          bibNumber: bibController.text,
        ),
        team: _selectedTeam!,
      );

      await widget.onSubmit(runner);
    } catch (e) {
      Logger.e('Error in runner input form: $e');
    }
  }

  void _handleTeamChange(Team? value) {
    // Clear pending team creation when team selection changes
    _pendingTeamCreation = null;
    _selectedTeam = value;

    // Update text controller with team name
    if (value != null && value.name != null) {
      teamController.text = value.name!;
      teamAbbreviationController.text = value.abbreviation ?? '';
    } else {
      teamController.text = '';
      teamAbbreviationController.text = '';
    }

    // Check if this is a new team that was created in the dialog
    if (value != null &&
        value.isValid &&
        !widget.teamOptions.contains(value) &&
        _currentTeamOptions.contains(value)) {
      // Mark this team as pending creation (will be created on form submit)
      _pendingTeamCreation = value;
    }

    validateTeam(value);
  }

  Widget _buildTeamField() {
    if (widget.requiredTeam != null && widget.requiredTeam!.name != null) {
      return Text(widget.requiredTeam!.name!);
    }
    if (_currentTeamOptions.isEmpty) {
      // If no team options, show text field for manual entry
      return textfield_utils.buildTextField(
        context: context,
        controller: teamController,
        hint: 'Enter team name',
        error: teamError,
        onChanged: (value) {
          // Create a temporary team object for validation
          final tempTeam =
              Team(name: value, abbreviation: Team.generateAbbreviation(value));
          _handleTeamChange(tempTeam);
        },
        setSheetState: setState,
      );
    } else {
      // Show dropdown with option to add new
      return _buildTeamDropdown();
    }
  }

  Widget _buildTeamDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Focus(
          onFocusChange: (hasFocus) {
            if (!hasFocus) {
              validateTeam(_selectedTeam);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: teamError != null
                  ? Colors.red.withAlpha((0.05 * 255).round())
                  : Colors.grey.withAlpha((0.05 * 255).round()),
              border: Border.all(
                  color: teamError != null
                      ? Colors.red.withAlpha((0.5 * 255).round())
                      : Colors.grey.withAlpha((0.5 * 255).round())),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: DropdownButtonHideUnderline(
              child: ButtonTheme(
                alignedDropdown: true,
                child: DropdownButton<Team?>(
                  value: _selectedTeam != null &&
                          _currentTeamOptions.contains(_selectedTeam)
                      ? _selectedTeam
                      : null,
                  hint: Text(
                      widget.onTeamCreated != null
                          ? 'Select Team or Create New'
                          : 'Select Team',
                      style: TextStyle(color: Colors.grey)),
                  isExpanded: true,
                  items: [
                    // Existing teams
                    ..._currentTeamOptions
                        .map((team) => DropdownMenuItem<Team?>(
                              value: team,
                              child: Text(team.name ?? ''),
                            )),
                    // Add new team option only if team creation is allowed
                    if (widget.onTeamCreated != null)
                      const DropdownMenuItem<Team?>(
                        value: null,
                        child: Row(
                          children: [
                            Icon(Icons.add, size: 16, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Create New Team',
                                style: TextStyle(color: Colors.blue)),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null && widget.onTeamCreated != null) {
                      _showCreateNewTeamDialog();
                    } else {
                      _handleTeamChange(value);
                    }
                  },
                ),
              ),
            ),
          ),
        ),
        if (teamError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(
              teamError!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  void _showCreateNewTeamDialog() async {
    // Use the CreateTeamSheet dialog instead of the inline dialog
    final newTeam = await sheet(
      context: context,
      body: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CreateTeamSheet(
          masterRace: widget.masterRace,
          createTeam: (Team createdTeam) async {
            Navigator.of(context).pop(createdTeam);
          },
        ),
      ),
    );

    if (newTeam != null) {
      setState(() {
        _currentTeamOptions.add(newTeam);
        _currentTeamOptions.sort((a, b) => a.name!.compareTo(b.name!));
      });
      _handleTeamChange(newTeam);
      if (widget.onTeamCreated != null) {
        await widget.onTeamCreated!(newTeam);
      }
    }
  }

  Widget buildInputField(String label, Widget inputWidget) {
    if (widget.useSheetLayout) {
      return textfield_utils.buildInputRow(
        label: label,
        inputWidget: inputWidget,
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          inputWidget,
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        buildInputField(
          'Name',
          textfield_utils.buildTextField(
            context: context,
            controller: nameController,
            hint: 'John Doe',
            error: nameError,
            onChanged: validateName,
            setSheetState: setState,
          ),
        ),
        const SizedBox(height: 16),
        buildInputField(
          'Grade',
          textfield_utils.buildTextField(
            context: context,
            controller: gradeController,
            hint: '9',
            keyboardType: TextInputType.number,
            error: gradeError,
            onChanged: validateGrade,
            setSheetState: setState,
          ),
        ),
        const SizedBox(height: 16),
        buildInputField(
          'Team',
          _buildTeamField(),
        ),
        if (widget.showBibField) ...[
          const SizedBox(height: 16),
          buildInputField(
            'Bib #',
            textfield_utils.buildTextField(
              context: context,
              controller: bibController,
              hint: '1234',
              error: bibError,
              onChanged: validateBib,
              setSheetState: setState,
            ),
          ),
        ],
        const SizedBox(height: 24),
        FullWidthButton(
          text: widget.submitButtonText,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          borderRadius: 8,
          isEnabled: !hasErrors(),
          onPressed: handleSubmit,
        ),
      ],
    );
  }
}
