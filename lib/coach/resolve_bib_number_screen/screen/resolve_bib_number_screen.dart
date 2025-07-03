import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/components/button_components.dart';
import 'package:xceleration/core/components/textfield_utils.dart';
import '../controller/resolve_bib_number_controller.dart';
import '../widgets/search_results.dart';
import '../../../core/theme/app_colors.dart';
import '../../race_screen/widgets/runner_record.dart';
import '../../../core/components/runner_input_form.dart';
import '../../../core/utils/database_helper.dart';
import 'package:xceleration/core/utils/color_utils.dart';

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

  Future<void> _loadSchools() async {
    // Load schools from the database
    final race = await DatabaseHelper.instance.getRaceById(_controller.raceId);

    // Check if widget is still mounted before calling setState
    if (!mounted) return;

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

  Future<void> _handleSubmitRunner(RunnerRecord runner) async {
    // Transfer form data to controller for resolution
    _controller.nameController.text = runner.name;
    _controller.gradeController.text = runner.grade.toString();
    _controller.schoolController.text = runner.school;

    // Now call the controller's method to create the runner
    await _controller.createNewRunner();
  }

  Widget _buildCreateNewForm() {
    return Expanded(
      child: SingleChildScrollView(
        child: RunnerInputForm(
          initialName: _controller.nameController.text,
          initialGrade: _controller.gradeController.text,
          initialSchool: _controller.schoolController.text,
          initialBib: _controller.record.bib,
          schoolOptions: _schools,
          raceId: _controller.raceId,
          onSubmit: _handleSubmitRunner,
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
    if (_controller.record.error == null) {
      // Use a post-frame callback instead of Future.microtask
      // This avoids the BuildContext async gap warning
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
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
