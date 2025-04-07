import 'package:flutter/material.dart';
import './textfield_utils.dart' as textfield_utils;
import '../../coach/race_screen/widgets/runner_record.dart';
import '../components/button_components.dart';

/// A shared widget for runner input form used across the app
class RunnerInputForm extends StatefulWidget {
  /// Controller for name input
  final TextEditingController? nameController;
  
  /// Controller for grade input
  final TextEditingController? gradeController;
  
  /// Controller for school input
  final TextEditingController? schoolController;
  
  /// Controller for bib input
  final TextEditingController? bibController;
  
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
    required this.nameController,
    required this.gradeController,
    required this.schoolController,
    required this.bibController,
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
  String? nameError;
  String? gradeError;
  String? schoolError;
  String? bibError;

  @override
  void initState() {
    super.initState();
    
    // Initialize with existing data if editing
    if (widget.initialRunner != null) {
      widget.nameController?.text = widget.initialRunner!.name;
      widget.gradeController?.text = widget.initialRunner!.grade.toString();
      widget.schoolController?.text = widget.initialRunner!.school;
      widget.bibController?.text = widget.initialRunner!.bib;
    }
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
    } else if (int.parse(value) < 1) {
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
    return schoolError != null ||
        bibError != null ||
        gradeError != null ||
        nameError != null ||
        widget.nameController!.text.isEmpty ||
        widget.gradeController!.text.isEmpty ||
        widget.schoolController!.text.isEmpty ||
        widget.bibController!.text.isEmpty;
  }

  void handleSubmit() {
    if (hasErrors()) {
      return;
    }
    
    try {
      final runner = RunnerRecord(
        name: widget.nameController!.text,
        grade: int.tryParse(widget.gradeController!.text) ?? 0,
        school: widget.schoolController!.text,
        bib: widget.bibController!.text,
        raceId: widget.raceId,
      );
      
      widget.onSubmit(runner);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
            controller: widget.nameController ?? TextEditingController(),
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
            controller: widget.gradeController ?? TextEditingController(),
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
                controller: widget.schoolController ?? TextEditingController(),
                hint: 'Enter school name',
                error: schoolError,
                onChanged: validateSchool,
                setSheetState: setState,
              )
            : textfield_utils.buildDropdown(
                controller: widget.schoolController ?? TextEditingController(),
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
              controller: widget.bibController ?? TextEditingController(),
              hint: '1234',
              error: bibError,
              onChanged: validateBib,
              setSheetState: setState,
            ),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FullWidthButton(
            text: widget.submitButtonText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            borderRadius: 8,
            isEnabled: !hasErrors(),
            onPressed: handleSubmit,
          ),
        ),
      ],
    );
  }
}
