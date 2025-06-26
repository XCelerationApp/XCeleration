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
  final Function(RunnerRecord) onSubmit;

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

  @override
  void initState() {
    super.initState();

    // Initialize controllers
    nameController = TextEditingController();
    gradeController = TextEditingController();
    schoolController = TextEditingController();
    bibController = TextEditingController();

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

  void handleSubmit() {
    if (hasErrors()) {
      return;
    }

    try {
      final runner = RunnerRecord(
        name: nameController.text,
        grade: int.tryParse(gradeController.text) ?? 0,
        school: schoolController.text,
        bib: bibController.text,
        raceId: widget.raceId,
      );

      widget.onSubmit(runner);
    } catch (e) {
      Logger.e('Error in runner input form: $e');
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
          'School',
          widget.schoolOptions.isEmpty
              ? textfield_utils.buildTextField(
                  context: context,
                  controller: schoolController,
                  hint: 'Enter school name',
                  error: schoolError,
                  onChanged: validateSchool,
                  setSheetState: setState,
                )
              : textfield_utils.buildDropdown(
                  controller: schoolController,
                  hint: 'Select School',
                  error: schoolError,
                  onChanged: validateSchool,
                  setSheetState: setState,
                  items: widget.schoolOptions..sort(),
                ),
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
