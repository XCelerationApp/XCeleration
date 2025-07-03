import 'package:flutter/material.dart';
import '../utils/logger.dart';
import './textfield_utils.dart' as textfield_utils;
import '../../coach/race_screen/widgets/runner_record.dart';
import '../components/button_components.dart';

/// A shared widget for runner input form used across the app
class RunnerInputForm extends StatefulWidget {
  /// Initial values for the form fields
  final String? initialName;
  final String? initialGrade;
  final String? initialSchool;
  final String? initialBib;

  /// List of available school/team names
  final List<String> schoolOptions;

  /// Callback when the form is submitted
  final Future<void> Function(RunnerRecord) onSubmit;

  /// Initial runner data (for editing)
  final RunnerRecord? initialRunner;

  /// Race ID associated with this runner
  final int raceId;

  /// Button text for the submit button
  final String submitButtonText;

  /// Whether to show the form in a sheet layout (with labels on left)
  final bool useSheetLayout;

  /// Whether to show the bib field
  final bool showBibField;

  /// Callback when a new team is created
  final Future<void> Function(String)? onTeamCreated;

  const RunnerInputForm({
    super.key,
    this.initialName,
    this.initialGrade,
    this.initialSchool,
    this.initialBib,
    required this.schoolOptions,
    required this.onSubmit,
    required this.raceId,
    this.initialRunner,
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
  late TextEditingController schoolController;
  late TextEditingController bibController;

  String? nameError;
  String? gradeError;
  String? schoolError;
  String? bibError;

  // Track updated school options including newly created teams
  late List<String> _currentSchoolOptions;

  // Track the team that needs to be created when form is submitted
  String? _pendingTeamCreation;

  @override
  void initState() {
    super.initState();

    // Initialize controllers
    nameController = TextEditingController();
    gradeController = TextEditingController();
    schoolController = TextEditingController();
    bibController = TextEditingController();

    // Initialize school options
    _currentSchoolOptions = List.from(widget.schoolOptions);

    // Initialize with existing data if editing
    if (widget.initialRunner != null) {
      nameController.text = widget.initialRunner!.name;
      gradeController.text = widget.initialRunner!.grade.toString();
      schoolController.text = widget.initialRunner!.school;
      bibController.text = widget.initialRunner!.bib;
    } else {
      // Use initial values if provided
      if (widget.initialName != null) nameController.text = widget.initialName!;
      if (widget.initialGrade != null) {
        gradeController.text = widget.initialGrade!;
      }
      if (widget.initialSchool != null) {
        schoolController.text = widget.initialSchool!;
      }
      if (widget.initialBib != null) bibController.text = widget.initialBib!;
    }
  }

  @override
  void dispose() {
    // Clean up controllers when the widget is disposed
    nameController.dispose();
    gradeController.dispose();
    schoolController.dispose();
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

  void validateSchool(String value) {
    if (value.isEmpty) {
      setState(() {
        schoolError = 'Please select a school';
      });
    } else {
      setState(() {
        schoolError = null;
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
    } else if (int.parse(value) < 0) {
      setState(() {
        bibError = 'Please enter a bib number greater than or equal to 0';
      });
    } else {
      setState(() {
        bibError = null;
      });
    }
  }

  bool hasErrors() {
    return schoolError != null ||
        bibError != null ||
        gradeError != null ||
        nameError != null ||
        nameController.text.isEmpty ||
        gradeController.text.isEmpty ||
        schoolController.text.isEmpty ||
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

      final runner = RunnerRecord(
        name: nameController.text,
        grade: int.tryParse(gradeController.text) ?? 0,
        school: schoolController.text,
        bib: bibController.text,
        raceId: widget.raceId,
      );

      await widget.onSubmit(runner);
    } catch (e) {
      Logger.e('Error in runner input form: $e');
    }
  }

  void _handleSchoolChange(String value) {
    // Clear pending team creation when school selection changes
    _pendingTeamCreation = null;

    // Check if this is a new team that was created in the dialog
    if (value.isNotEmpty &&
        !widget.schoolOptions.contains(value) &&
        _currentSchoolOptions.contains(value)) {
      // Mark this team as pending creation (will be created on form submit)
      _pendingTeamCreation = value;
    }

    validateSchool(value);
  }

  Widget _buildSchoolField() {
    if (_currentSchoolOptions.isEmpty) {
      // If no school options, show text field for manual entry
      return textfield_utils.buildTextField(
        context: context,
        controller: schoolController,
        hint: 'Enter school name',
        error: schoolError,
        onChanged: (value) {
          _pendingTeamCreation = value;
        },
        setSheetState: setState,
      );
    } else {
      // Show dropdown with option to add new
      return _buildSchoolDropdown();
    }
  }

  Widget _buildSchoolDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Focus(
          onFocusChange: (hasFocus) {
            if (!hasFocus) {
              _handleSchoolChange(schoolController.text);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: schoolError != null
                  ? Colors.red.withAlpha((0.05 * 255).round())
                  : Colors.grey.withAlpha((0.05 * 255).round()),
              border: Border.all(
                  color: schoolError != null
                      ? Colors.red.withAlpha((0.5 * 255).round())
                      : Colors.grey.withAlpha((0.5 * 255).round())),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: DropdownButtonHideUnderline(
              child: ButtonTheme(
                alignedDropdown: true,
                child: DropdownButton<String>(
                  value: (schoolController.text.isEmpty ||
                          !_currentSchoolOptions
                              .contains(schoolController.text))
                      ? null
                      : schoolController.text,
                  hint: Text(
                      widget.onTeamCreated != null
                          ? 'Select School or Create New'
                          : 'Select School',
                      style: TextStyle(color: Colors.grey)),
                  isExpanded: true,
                  items: [
                    // Existing schools
                    ..._currentSchoolOptions.map((item) => DropdownMenuItem(
                          value: item,
                          child: Text(item),
                        )),
                    // Add new team option only if team creation is allowed
                    if (widget.onTeamCreated != null)
                      const DropdownMenuItem(
                        value: '__CREATE_NEW__',
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
                    if (value == '__CREATE_NEW__') {
                      _showCreateNewTeamDialog();
                    } else {
                      setState(() => schoolController.text = value ?? '');
                      _handleSchoolChange(value ?? '');
                    }
                  },
                ),
              ),
            ),
          ),
        ),
        if (schoolError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(
              schoolError!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  void _showCreateNewTeamDialog() {
    final TextEditingController newTeamController = TextEditingController();
    String? newTeamError;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create New Team'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Enter the name for the new team:'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newTeamController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Team name',
                      border: const OutlineInputBorder(),
                      errorText: newTeamError,
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        if (value.trim().isEmpty) {
                          newTeamError = 'Please enter a team name';
                        } else if (_currentSchoolOptions
                            .contains(value.trim())) {
                          newTeamError = 'Team already exists';
                        } else {
                          newTeamError = null;
                        }
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: newTeamError == null &&
                          newTeamController.text.trim().isNotEmpty
                      ? () {
                          final newTeamName = newTeamController.text.trim();

                          // Add to local options and update controller
                          setState(() {
                            _currentSchoolOptions.add(newTeamName);
                            _currentSchoolOptions.sort();
                            schoolController.text = newTeamName;
                          });

                          // Mark as pending creation (will be created when form is submitted)
                          _pendingTeamCreation = newTeamName;

                          _handleSchoolChange(newTeamName);
                          Navigator.of(context).pop();
                        }
                      : null,
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
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
          'School',
          _buildSchoolField(),
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
