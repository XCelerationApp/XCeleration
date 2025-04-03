import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xcelerate/core/components/textfield_utils.dart';
import '../widgets/action_button.dart';
import '../widgets/search_results.dart';
import '../../../core/theme/app_colors.dart';
import '../../race_screen/widgets/runner_record.dart';
import '../../../core/components/runner_input_form.dart';
import '../controller/resolve_bib_number_controller.dart';
import '../../../utils/database_helper.dart';

class ResolveBibNumberScreen extends StatefulWidget {
  final List<RunnerRecord> records;
  final int raceId;
  final RunnerRecord record;
  final Function(RunnerRecord) onComplete;

  const ResolveBibNumberScreen({
    super.key,
    required this.records,
    required this.raceId,
    required this.record,
    required this.onComplete,
  });

  @override
  State<ResolveBibNumberScreen> createState() => _ResolveBibNumberScreenState();
}

class _ResolveBibNumberScreenState extends State<ResolveBibNumberScreen> {
  late ResolveBibNumberController _controller;
  List<String> _schools = [];

  @override
  void initState() {
    super.initState();
    _controller = ResolveBibNumberController(
      records: widget.records,
      raceId: widget.raceId,
      onComplete: widget.onComplete,
      record: widget.record,
    );
    _controller.setContext(context);
    _loadSchools();
  }

  @override
  void dispose() {
    // Controller will be disposed through the Provider
    super.dispose();
  }

  Future<void> _loadSchools() async {
    // Load schools from the database
    final race = await DatabaseHelper.instance.getRaceById(_controller.raceId);
    if (race != null) {
      setState(() {
        _schools = race.teams;
      });
    } else {
      setState(() {
        _schools = [];
      });
    }
  }

  void _handleSubmitRunner(RunnerRecord runner) {
    // Transfer form data to controllers
    _controller.nameController.text = runner.name;
    _controller.gradeController.text = runner.grade.toString();
    _controller.schoolController.text = runner.school;
    
    // The resolve bib number controller needs the bib from the record being resolved
    // not from the form (which might be hidden anyway)
    
    // Now call the controller's method to create the runner
    _controller.createNewRunner();
  }

  Widget _buildCreateNewForm() {
    return Expanded(
      child: SingleChildScrollView(
        child: RunnerInputForm(
          nameController: _controller.nameController,
          gradeController: _controller.gradeController,
          schoolController: _controller.schoolController,
          bibController: TextEditingController(text: _controller.record.bib),
          schoolOptions: _schools,
          raceId: _controller.raceId,
          onSubmit: _handleSubmitRunner,
          submitButtonText: 'Create New Runner',
          useSheetLayout: false,
          showBibField: false,
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_controller.record.error == null) {
      Future.microtask(() => Navigator.of(context).pop());
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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
                      color: AppColors.primaryColor.withOpacity(0.3),
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
                            color: AppColors.primaryColor.withOpacity(0.1),
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
                                'We could not identify this runner with bib number ${_controller.record.bib}.\nPlease choose an existing runner or create a new one.',
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
                      child: ActionButton(
                        label: 'Choose Existing Runner',
                        icon: Icons.person_search,
                        isSelected: !_controller.showCreateNew,
                        onPressed: () {
                          setState(() {
                            _controller.showCreateNew = false;
                            _controller.searchRunners(_controller.searchController.text);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      flex: 1,
                      child: ActionButton(
                        label: 'Create New Runner',
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
                                onChanged: (value) => controller.searchRunners(value),
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
