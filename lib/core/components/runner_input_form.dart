import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/logger.dart';
import './textfield_utils.dart' as textfield_utils;
import '../components/button_components.dart';
import '../../shared/models/database/team.dart';
import '../../shared/models/database/race_runner.dart';
import '../../shared/models/database/runner.dart';

/// A shared widget for runner input form used across the app
class RunnerInputForm extends StatefulWidget {
  /// Race ID associated with this runner
  final int raceId;

  /// List of available team names
  final List<Team> teamOptions;

  /// Callback when the form is submitted
  final Future<void> Function(RaceRunner) onSubmit;

  /// Initial runner data (for editing)
  final RaceRunner? initialRaceRunner;

  /// Required team data (for creating a new runner with a specific team)
  final Team? runnerTeam;

  /// Button text for the submit button
  final String submitButtonText;

  /// Whether to show the form in a sheet layout (with labels on left)
  final bool useSheetLayout;

  /// Whether to show the bib field
  final bool showBibField;

  /// Optional external bib controller (if not provided, one will be created)
  final TextEditingController? bibController;

  /// Lookup function to find an existing runner by bib
  final Future<Runner?> Function(String bib) getRunnerByBib;

  const RunnerInputForm({
    super.key,
    required this.raceId,
    required this.teamOptions,
    required this.onSubmit,
    required this.getRunnerByBib,
    this.initialRaceRunner,
    this.runnerTeam,
    this.submitButtonText = 'Create',
    this.useSheetLayout = true,
    this.showBibField = true,
    this.bibController,
  });

  @override
  State<RunnerInputForm> createState() => _RunnerInputFormState();
}

class _RunnerInputFormState extends State<RunnerInputForm> {
  late final bool _isEditing;
  // Internal controllers that will be managed by this widget
  late TextEditingController nameController;
  late TextEditingController gradeController;
  late TextEditingController teamController;
  late TextEditingController teamAbbreviationController;
  late TextEditingController bibController;
  bool _externalBibController = false;

  String? nameError;
  String? gradeError;
  String? teamError;
  String? teamAbbreviationError;
  String? bibError;
  String? bibWarning;
  String? _originalBib;
  // Kept for backward compatibility during refactors; original snapshot is in _originalRaceRunner
  bool _isSubmitting = false;
  RaceRunner? _originalRaceRunner;

  Timer? _bibDebounce;
  Timer? _gradeDebounce;

  // Track updated team options including newly created teams
  late List<Team> _currentTeamOptions;

  // Track the currently selected team
  Team? _selectedTeam;

  @override
  void initState() {
    super.initState();

    _isEditing = widget.initialRaceRunner != null;

    // Initialize controllers
    nameController = TextEditingController();
    gradeController = TextEditingController();
    teamController = TextEditingController();
    teamAbbreviationController = TextEditingController();

    // Use external bibController if provided, otherwise create our own
    if (widget.bibController != null) {
      bibController = widget.bibController!;
      _externalBibController = true;
    } else {
      bibController = TextEditingController();
    }

    // Initialize team options
    _currentTeamOptions = List.from(widget.teamOptions);

    // Initialize with existing data if editing
    if (_isEditing) {
      // Handle null values that can occur with placeholder runners for unknown conflicts
      nameController.text = widget.initialRaceRunner!.runner.name ?? '';
      gradeController.text =
          widget.initialRaceRunner!.runner.grade?.toString() ?? '';
      teamController.text = widget.initialRaceRunner!.team.name ?? '';
      bibController.text = widget.initialRaceRunner!.runner.bibNumber ?? '';
      _originalBib = widget.initialRaceRunner!.runner.bibNumber ?? '';
      _selectedTeam = widget.initialRaceRunner!.team;
      teamAbbreviationController.text =
          widget.initialRaceRunner!.team.abbreviation ?? '';

      // Save a snapshot of the original race runner for comparison
      // Only create snapshot if all required fields are present (skip for placeholder runners)
      if (widget.initialRaceRunner!.runner.name != null &&
          widget.initialRaceRunner!.runner.grade != null &&
          widget.initialRaceRunner!.team.name != null) {
        _originalRaceRunner = RaceRunner.from(widget.initialRaceRunner!);
      }

      // Align the selected team with the exact instance from options (by id)
      // Only do this if the team has a valid teamId (placeholder teams for unknown conflicts don't)
      if (_selectedTeam != null && _selectedTeam!.teamId != null) {
        try {
          final match = _currentTeamOptions
              .firstWhere((t) => t.teamId == _selectedTeam!.teamId);
          _selectedTeam = match;
        } catch (_) {
          // For placeholder teams from unknown conflicts, just keep the original team
          Logger.d(
              'Team not found in options, keeping original team (likely placeholder)');
        }
      }
    } else {
      // Creating: require runnerTeam to be passed and set selection, otherwise error
      if (widget.runnerTeam == null || widget.runnerTeam!.teamId == null) {
        throw Exception('runnerTeam is required when creating a runner');
      }
      _selectedTeam = widget.runnerTeam;
      teamController.text = widget.runnerTeam!.name ?? '';
      teamAbbreviationController.text = widget.runnerTeam!.abbreviation ?? '';
    }
  }

  @override
  void dispose() {
    _bibDebounce?.cancel();
    _gradeDebounce?.cancel();
    // Clean up controllers when the widget is disposed
    nameController.dispose();
    gradeController.dispose();
    teamController.dispose();
    teamAbbreviationController.dispose();

    // Only dispose bibController if it's not an external one
    if (!_externalBibController) {
      bibController.dispose();
    }

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
    _gradeDebounce?.cancel();
    final current = value;
    _gradeDebounce = Timer(const Duration(milliseconds: 500), () {
      // If input changed while waiting, skip
      if (gradeController.text != current) return;
      if (current.isEmpty) {
        setState(() {
          gradeError = 'Please enter a grade';
        });
      } else if (int.tryParse(current) == null) {
        setState(() {
          gradeError = 'Please enter a valid grade number';
        });
      } else {
        final grade = int.parse(current);
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
    });
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
    // Synchronous validation
    if (value.isEmpty) {
      setState(() {
        bibError = 'Please enter a bib number';
        bibWarning = null;
      });
    } else if (int.tryParse(value) == null) {
      setState(() {
        bibError = 'Please enter a valid bib number';
        bibWarning = null;
      });
    } else if (int.parse(value) <= 0) {
      setState(() {
        bibError = 'Please enter a bib number greater than 0';
        bibWarning = null;
      });
    } else {
      setState(() {
        bibError = null;
        bibWarning = null;
      });

      // Debounced uniqueness check against DB
      _bibDebounce?.cancel();
      final trimmed = value.trim();
      _bibDebounce = Timer(const Duration(milliseconds: 500), () async {
        // If the input changed during await, don't overwrite
        if (bibController.text.trim() != trimmed) return;
        final existingRunner = await widget.getRunnerByBib(trimmed);
        if (!mounted) return;
        final bool changedBib =
            _isEditing && (_originalBib != null) && (trimmed != _originalBib);
        if (!_isEditing) {
          final isUnique = await _checkBibUnique(trimmed);
          setState(() {
            bibWarning = null;
            bibError = isUnique ? null : 'Bib number already exists';
          });
        } else {
          if (changedBib &&
              existingRunner != null &&
              existingRunner.runnerId !=
                  (widget.initialRaceRunner?.runner.runnerId ?? -1)) {
            setState(() {
              bibError = null;
              bibWarning =
                  'Warning: A runner with this bib already exists, you will overwrite the existing runner if you save';
            });
          } else {
            setState(() {
              bibError = null;
              bibWarning = null;
            });
          }
        }
      });
    }
  }

  Future<bool> _checkBibUnique(String bib) async {
    try {
      final existingRunner = await widget.getRunnerByBib(bib);
      if (existingRunner == null) return true;
      // Allow the same bib if editing the same runner
      final editingId = widget.initialRaceRunner?.runner.runnerId;
      if (editingId != null && existingRunner.runnerId == editingId) {
        return true;
      }
      return false;
    } catch (_) {
      // If DB check fails, don't block the user; treat as unique
      return true;
    }
  }

  bool hasErrors() {
    final isCreating = !_isEditing;
    return teamError != null && isCreating ||
        bibError != null ||
        gradeError != null ||
        nameError != null ||
        nameController.text.isEmpty ||
        gradeController.text.isEmpty ||
        bibController.text.isEmpty;
  }

  Future<void> handleSubmit() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
    });
    // Validate all fields first, then update UI once
    final isValid = await _validateAllForSubmit();
    if (!isValid) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
      return;
    }

    try {
      final runner = RaceRunner(
        raceId: widget.raceId,
        runner: Runner(
          runnerId: widget.initialRaceRunner?.runner.runnerId,
          name: nameController.text,
          grade: int.tryParse(gradeController.text) ?? 0,
          bibNumber: bibController.text,
        ),
        team: _selectedTeam ?? widget.runnerTeam ?? Team(),
      );

      await widget.onSubmit(runner);
    } catch (e) {
      Logger.e('Error in runner input form: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<bool> _validateAllForSubmit() async {
    String? nextNameError;
    String? nextGradeError;
    String? nextTeamError;
    String? nextBibError;
    String? nextBibWarning;

    // Name
    final name = nameController.text.trim();
    if (name.isEmpty) {
      nextNameError = 'Please enter a name';
    }

    // Grade
    final int? gradeNum = int.tryParse(gradeController.text.trim());
    if (gradeNum == null) {
      nextGradeError = 'Please enter a grade';
    } else if (gradeNum < 9 || gradeNum > 12) {
      nextGradeError = 'Grade must be between 9 and 12';
    }

    // Team (Creation requires runnerTeam; Editing requires a selection present)
    if (!_isEditing) {
      if (widget.runnerTeam == null || widget.runnerTeam!.teamId == null) {
        nextTeamError = 'Internal error: runnerTeam is required for creation';
      }
    } else if (_selectedTeam == null) {
      nextTeamError = 'Please select a team';
    }

    // Bib
    final bib = bibController.text.trim();
    if (bib.isEmpty) {
      nextBibError = 'Please enter a bib number';
    } else if (int.tryParse(bib) == null) {
      nextBibError = 'Please enter a valid bib number';
    } else if ((int.tryParse(bib) ?? 0) <= 0) {
      nextBibError = 'Please enter a bib number greater than 0';
    } else {
      if (!_isEditing) {
        final isUnique = await _checkBibUnique(bib);
        if (!isUnique) {
          nextBibError = 'Bib number already exists';
        }
      } else {
        final changedBib = (_originalBib != null) && (bib != _originalBib);
        if (changedBib) {
          final existingRunner = await widget.getRunnerByBib(bib);
          if (existingRunner != null &&
              existingRunner.runnerId !=
                  (widget.initialRaceRunner?.runner.runnerId ?? -1)) {
            // Show warning; allow submit (conflict resolved later)
            nextBibWarning =
                'Warning: A runner with this bib already exists. You will overwrite the existing runner if you save.';
          }
        }
      }
    }

    // Apply all at once
    setState(() {
      nameError = nextNameError;
      gradeError = nextGradeError;
      teamError = nextTeamError;
      bibError = nextBibError;
      bibWarning = nextBibWarning;
    });

    return nextNameError == null &&
        nextGradeError == null &&
        nextTeamError == null &&
        nextBibError == null &&
        name.isNotEmpty &&
        bib.isNotEmpty;
  }

  void _handleTeamChange(Team? value) {
    _selectedTeam = value;

    // Update text controller with team name
    if (value != null && value.name != null) {
      teamController.text = value.name!;
      teamAbbreviationController.text = value.abbreviation ?? '';
    } else {
      teamController.text = '';
      teamAbbreviationController.text = '';
    }

    validateTeam(value);
  }

  Widget _buildTeamField() {
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
      // Show dropdown
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
                    hint: Text('Select Team',
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
                    ],
                    onChanged: _handleTeamChange),
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
    return SingleChildScrollView(
      child: Column(
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
          if (_isEditing)
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
                warning: bibWarning,
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
            isEnabled: !_isSubmitting &&
                !hasErrors() &&
                (!_isEditing || _hasChanges()),
            onPressed: !_isSubmitting ? handleSubmit : null,
          ),
        ],
      ),
    );
  }

  bool _hasChanges() {
    if (!_isEditing) return true;

    // For placeholder runners (unknown conflicts), always consider as having changes
    if (_originalRaceRunner == null) return true;

    final orig = _originalRaceRunner!;

    final currentName = nameController.text.trim();
    final currentGrade = int.tryParse(gradeController.text.trim()) ?? 0;
    final currentBib = bibController.text.trim();
    final currentTeamId = (widget.runnerTeam ?? _selectedTeam)?.teamId;

    final nameChanged = (orig.runner.name ?? '') != currentName;
    final gradeChanged = (orig.runner.grade ?? 0) != currentGrade;
    final bibChanged = (orig.runner.bibNumber ?? '') != currentBib;
    final teamChanged = (orig.team.teamId) != currentTeamId;

    return nameChanged || gradeChanged || bibChanged || teamChanged;
  }
}
