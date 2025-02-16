import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter/services.dart';
import '../utils/app_colors.dart';
import '../utils/dialog_utils.dart';
import '../utils/sheet_utils.dart';
import '../database_helper.dart';
import '../file_processing.dart';

// Models
class Team {
  final String name;
  final Color color;

  Team({required this.name, required this.color});
}

class Runner {
  final String name;
  final int grade;
  final String school;
  final String bibNumber;
  final int? runnerId;
  final int? raceRunnerId;

  Runner({
    required this.name,
    required this.grade,
    required this.school,
    required this.bibNumber,
    this.runnerId,
    this.raceRunnerId,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'grade': grade,
    'school': school,
    'bib_number': bibNumber,
    if (runnerId != null) 'runner_id': runnerId,
    if (raceRunnerId != null) 'race_runner_id': raceRunnerId,
  };

  factory Runner.fromMap(Map<String, dynamic> map) => Runner(
    name: map['name'],
    grade: map['grade'],
    school: map['school'],
    bibNumber: map['bib_number'],
    runnerId: map['runner_id'],
    raceRunnerId: map['race_runner_id'],
  );

  Runner copyWith({
    String? name,
    int? grade,
    String? school,
    String? bibNumber,
  }) {
    return Runner(
      name: name ?? this.name,
      grade: grade ?? this.grade,
      school: school ?? this.school,
      bibNumber: bibNumber ?? this.bibNumber,
      runnerId: this.runnerId,
      raceRunnerId: this.raceRunnerId,
    );
  }
}

// Components
class RunnerTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isNumeric;
  final String? initialValue;

  const RunnerTextField({
    super.key,
    required this.controller,
    required this.label,
    this.isNumeric = false,
    this.initialValue,
  });

  @override
  Widget build(BuildContext context) {
    if (initialValue != null) {
      controller.text = initialValue!;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(color: Colors.blue, width: 2.0),
          ),
        ),
      ),
    );
  }
}

class RunnerListItem extends StatefulWidget {
  final Runner runner;
  final Function(String) onActionSelected;
  final List<Team> teamData;

  const RunnerListItem({
    super.key,
    required this.runner,
    required this.onActionSelected,
    required this.teamData,
  });

  @override
  State<RunnerListItem> createState() => _RunnerListItemState();
}

class _RunnerListItemState extends State<RunnerListItem> {
  @override
  Widget build(BuildContext context) {
    final team = widget.teamData.firstWhereOrNull((team) => team.name == widget.runner.school);
    final bibColor = team != null ? team.color : AppColors.mediumColor;
    
    return Slidable(
      key: Key(widget.runner.bibNumber),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => widget.onActionSelected('Edit'),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            // label: 'Edit',
          ),
          SlidableAction(
            onPressed: (_) => widget.onActionSelected('Delete'),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            // label: 'Delete',
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bibColor.withOpacity(0.1),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: Text(
                          widget.runner.name,
                          style: const TextStyle(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Text(
                          widget.runner.school,
                          style: const TextStyle(fontSize: 16, color: Colors.black),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Text(
                          widget.runner.grade.toString(),
                          style: const TextStyle(fontSize: 16, color: Colors.black),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Text(
                          widget.runner.bibNumber,
                          style: TextStyle(
                            color: bibColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String searchAttribute;
  final Function(String) onSearchChanged;
  final Function(String?) onAttributeChanged;
  final VoidCallback onDeleteAll;

  const SearchBar({
    super.key,
    required this.controller,
    required this.searchAttribute,
    required this.onSearchChanged,
    required this.onAttributeChanged,
    required this.onDeleteAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Search',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF606060)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primaryColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.navBarColor),
              ),
            ),
            onChanged: onSearchChanged,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.navBarColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButton<String>(
                value: searchAttribute,
                onChanged: onAttributeChanged,
                items: ['Bib Number', 'Name', 'Grade', 'School']
                    .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                icon: const Icon(Icons.arrow_drop_down, color: AppColors.navBarColor),
                iconSize: 30,
                isExpanded: true,
                focusColor: AppColors.backgroundColor,
                underline: const SizedBox(),
                style: const TextStyle(color: AppColors.navBarColor, fontSize: 16),
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete),
          tooltip: 'Delete All Runners',
          onPressed: onDeleteAll,
        ),
      ],
    );
  }
}

// Main Screen
class RunnersManagementScreen extends StatefulWidget {
  final int raceId;
  final bool isTeam;

  const RunnersManagementScreen({
    super.key,
    required this.raceId,
    required this.isTeam,
  });

  @override
  State<RunnersManagementScreen> createState() => _RunnersManagementScreenState();
}

class _RunnersManagementScreenState extends State<RunnersManagementScreen> {
  List<Runner> _runners = [];
  List<Runner> _filteredRunners = [];
  List<Team> _teams = [];
  bool _isLoading = true;
  String _searchAttribute = 'Bib Number';
  final TextEditingController _searchController = TextEditingController();
  
  // Sheet controllers
  TextEditingController? _nameController;
  TextEditingController? _gradeController;
  TextEditingController? _schoolController;
  TextEditingController? _bibController;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadRunners(),
      _loadTeams(),
    ]);
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _disposeControllers();
    super.dispose();
  }

  void _initControllers() {
    _disposeControllers(); // Clean up any existing controllers first
    _nameController = TextEditingController();
    _gradeController = TextEditingController();
    _schoolController = TextEditingController();
    _bibController = TextEditingController();
  }

  void _disposeControllers() {
    _nameController?.dispose();
    _gradeController?.dispose();
    _schoolController?.dispose();
    _bibController?.dispose();
    _nameController = null;
    _gradeController = null;
    _schoolController = null;
    _bibController = null;
  }

  Future<void> _loadTeams() async {
    final race = await DatabaseHelper.instance.getRaceById(widget.raceId);
    if (mounted) {
      setState(() {
        _teams.clear();
        for (var i = 0; i < race!.teams.length; i++) {
          _teams.add(Team(name: race.teams[i], color: race.teamColors[i]));
        }
      });
    }
  }

  Future<void> _loadRunners() async {
    final runners = await DatabaseHelper.instance.getRaceRunners(widget.raceId);
    if (mounted) {
      setState(() {
        _runners = runners.map(Runner.fromMap).toList();
        _filteredRunners = _runners;
        _sortRunners();
      });
    }
  }

  void _sortRunners() {
    _runners.sort((a, b) {
      final schoolCompare = a.school.compareTo(b.school);
      if (schoolCompare != 0) return schoolCompare;
      return a.name.compareTo(b.name);
    });
  }

  void _filterRunners(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredRunners = List.from(_runners);
      } else {
        _filteredRunners = _runners.where((runner) {
          final value = switch (_searchAttribute) {
            'Bib Number' => runner.bibNumber,
            'Name' => runner.name.toLowerCase(),
            'Grade' => runner.grade.toString(),
            'School' => runner.school.toLowerCase(),
            String() => '',
          };
          return value.contains(query.toLowerCase());
        }).toList();
    }});
  }

  Future<void> _handleRunnerAction(String action, Runner runner) async {
    switch (action) {
      case 'Edit':
        await _showRunnerSheet(
          context: context,
          runner: runner,
        );
        break;
      case 'Delete':
        final confirmed = await DialogUtils.showConfirmationDialog(
          context,
          title: 'Confirm Deletion',
          content: 'Are you sure you want to delete this runner?',
        );
        if (confirmed) {
          await _deleteRunner(runner);
          await _loadRunners();
        }
        break;
    }
  }

  Future<void> _deleteRunner(Runner runner) async {
    if (widget.isTeam) {
      await DatabaseHelper.instance.deleteTeamRunner(runner.bibNumber);
    } else {
      await DatabaseHelper.instance.deleteRaceRunner(widget.raceId, runner.bibNumber);
    }
  }

  Widget _buildListTitles() {
    final double fontSize = 15;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                'Name',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                'School',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                'Gr.',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                'Bib',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundColor,
      // child: Padding(
        // padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            _buildActionButtons(),
            const SizedBox(height: 20),
            if (_runners.isNotEmpty) _buildSearchSection(),
            const SizedBox(height: 10),
            _buildListTitles(),
            Expanded(
              child: _buildRunnersList(),
            ),
          ],
        ),
      // ),
    );
  }


  // UI Building Methods
  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          'Add Runner',
          onPressed: () => _showRunnerSheet(context: context, runner: null),
        ),
        _buildActionButton(
          'Load Spreadsheet',
          onPressed: _handleSpreadsheetLoad,
        ),
      ],
    );
  }

  Widget _buildActionButton(String text, {required VoidCallback onPressed}) {
    return Padding(
        padding: const EdgeInsets.all(5.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                fixedSize: Size(125, 50),
                padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10),
                backgroundColor: AppColors.primaryColor,
              ),
              child: Center(
                child: Text(
                  text,
                  style: TextStyle(fontSize: 15, color: Colors.white),
                ),
              ),
            );
          },
        ),
    );
  }

  Widget _buildSearchSection() {
    return SearchBar(
      controller: _searchController,
      searchAttribute: _searchAttribute,
      onSearchChanged: _filterRunners,
      onAttributeChanged: (value) {
        setState(() {
          _searchAttribute = value!;
          _filterRunners(_searchController.text);
        });
      },
      onDeleteAll: () => _confirmDeleteAllRunners(context),
    );
  }

  Widget _buildRunnersList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredRunners.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty
              ? 'No Runners'
              : 'No runners found',
          style: const TextStyle(fontSize: 24),
        ),
      );
    }

    // Group runners by school
    final groupedRunners = <String, List<Runner>>{};
    for (var runner in _filteredRunners) {
      if (!groupedRunners.containsKey(runner.school)) {
        groupedRunners[runner.school] = [];
      }
      groupedRunners[runner.school]!.add(runner);
    }

    // Sort schools alphabetically
    final sortedSchools = groupedRunners.keys.toList()..sort();

    return ListView.builder(
      itemCount: sortedSchools.length,
      itemBuilder: (context, index) {
        final school = sortedSchools[index];
        final schoolRunners = groupedRunners[school]!;
        final team = _teams.firstWhereOrNull((team) => team.name == school);
        final schoolColor = team != null ? team.color : Colors.blueGrey[300];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 1, thickness: 1, color: Colors.grey),
            Container(
              color: schoolColor?.withOpacity(0.1) ?? Colors.grey.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                school,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: schoolColor,
                ),
              ),
            ),
            ...schoolRunners.map((runner) => RunnerListItem(
              runner: runner,
              teamData: _teams,
              onActionSelected: (action) => _handleRunnerAction(action, runner),
            )),
          ],
        );
      },
    );
  }
  // Dialog and Action Methods
  Future<void> _showRunnerSheet({
    required BuildContext context,
    Runner? runner,
  }) async {
    final title = runner == null ? 'Add Runner' : 'Edit Runner';
    String? nameError;
    String? gradeError;
    String? schoolError;
    String? bibError;
    
    // Initialize controllers
    _initControllers();

    if (runner != null) {
      _nameController?.text = runner.name;
      _gradeController?.text = runner.grade.toString();
      _schoolController?.text = runner.school;
      _bibController?.text = runner.bibNumber;
    }

    try {
      await showModalBottomSheet(
        isScrollControlled: true,
        enableDrag: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  createSheetHandle(height: 10, width: 60),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFormRow(
                        label: 'Name',
                        controller: _nameController!,
                        hint: 'John Doe',
                        error: nameError,
                        onChanged: (value) {
                          if (value.isEmpty) {
                            setSheetState(() {
                              nameError = 'Please enter a name';
                            });
                          } else {
                            setSheetState(() {
                              nameError = null;
                            });
                          }
                        },
                        setSheetState: setSheetState,
                      ),
                      const SizedBox(height: 16),
                      _buildFormRow(
                        label: 'Grade',
                        controller: _gradeController!,
                        hint: '9',
                        keyboardType: TextInputType.number,
                        error: gradeError,
                        onChanged: (value) {
                          if (value.isEmpty) {
                            setSheetState(() {
                              gradeError = 'Please enter a grade';
                            });
                          } else if (int.tryParse(value) == null) {
                            setSheetState(() {
                              gradeError = 'Please enter a valid grade number';
                            });
                          } else {
                            final grade = int.parse(value);
                            if (grade < 9 || grade > 12) {
                              setSheetState(() {
                                gradeError = 'Grade must be between 9 and 12';
                              });
                            } else {
                              setSheetState(() {
                                gradeError = null;
                              });
                            }
                          }
                        },
                        setSheetState: setSheetState,
                      ),
                      const SizedBox(height: 16),
                      _buildFormRow(
                        label: 'School',
                        controller: _schoolController!,
                        hint: 'School Name',
                        error: schoolError,
                        onChanged: (value) {
                          if (value.isEmpty) {
                            setSheetState(() {
                              schoolError = 'Please select a school';
                            });
                          } else {
                            setSheetState(() {
                              schoolError = null;
                            });
                          }
                        },
                        setSheetState: setSheetState,
                      ),
                      const SizedBox(height: 16),
                      _buildFormRow(
                        label: 'Bib #',
                        controller: _bibController!,
                        hint: '1234',
                        keyboardType: TextInputType.number,
                        error: bibError,
                        onChanged: (value) {
                          if (value.isEmpty) {
                            setSheetState(() {
                              bibError = 'Please enter a bib number';
                            });
                          } else if (int.tryParse(value) == null) {
                            setSheetState(() {
                              bibError = 'Please enter a valid bib number';
                            });
                          } else {
                            setSheetState(() {
                              bibError = null;
                            });
                          }
                        },
                        setSheetState: setSheetState,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (schoolError != null || bibError != null || gradeError != null || nameError != null || _nameController!.text.isEmpty || _gradeController!.text.isEmpty || _schoolController!.text.isEmpty || _bibController!.text.isEmpty)
                            ? AppColors.primaryColor.withOpacity(.5)
                            : AppColors.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        if (schoolError != null || bibError != null || gradeError != null || nameError != null || _nameController!.text.isEmpty || _gradeController!.text.isEmpty || _schoolController!.text.isEmpty || _bibController!.text.isEmpty) return;
                        try {
                          final newRunner = Runner(
                            name: _nameController!.text,
                            grade: int.tryParse(_gradeController!.text) ?? 0,
                            school: _schoolController!.text,
                            bibNumber: _bibController!.text,
                            runnerId: runner?.runnerId,
                            raceRunnerId: runner?.raceRunnerId,
                          );

                          await _handleRunnerSubmission(newRunner);
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                      child: Text(
                        runner == null ? 'Create' : 'Save',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } finally {
      // Always dispose controllers when sheet is closed
      _disposeControllers();
    }
  }

  Widget _buildFormRow({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    String? error,
    required Function(String) onChanged,
    required StateSetter setSheetState,
  }) {
    if (label == 'School') {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StatefulBuilder(
              builder: (context, setState) {
                final schools = _teams.map((t) => t.name).toList()..sort();
                final isCustom = !schools.contains(controller.text) && controller.text.isNotEmpty;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Focus(
                      onFocusChange: (hasFocus) {
                        if (!hasFocus) {
                          onChanged(controller.text);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: error != null ? Colors.red : Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: ButtonTheme(
                            alignedDropdown: true,
                            child: DropdownButton<String>(
                              value: isCustom ? null : (controller.text.isEmpty ? null : controller.text),
                              hint: Text(hint, style: const TextStyle(color: Colors.grey)),
                              isExpanded: true,
                              items: [
                                ...schools.map((school) => DropdownMenuItem(
                                  value: school,
                                  child: Text(school),
                                )),
                              ],
                              onChanged: (value) {
                                setState(() => controller.text = value ?? '');
                                onChanged(value ?? '');
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 12),
                        child: Text(
                          error,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Focus(
                onFocusChange: (hasFocus) {
                  if (!hasFocus) {
                    onChanged(controller.text);
                  }
                },
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: error != null ? Colors.red : Colors.grey),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: error != null ? Colors.red : Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: error != null ? Colors.red : AppColors.primaryColor),
                    ),
                    errorText: error,
                    errorStyle: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                  onTapOutside: (_) {
                    onChanged(controller.text);
                  },
                  onChanged: (value) {
                    onChanged(value);
                  }
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleRunnerSubmission(Runner runner) async {
    try {
      // Check if a runner with this bib number already exists
      dynamic existingRunner;
      if (widget.isTeam) {
        existingRunner = await DatabaseHelper.instance.getTeamRunnerByBib(runner.bibNumber);
      } else {
        existingRunner = await DatabaseHelper.instance.getRaceRunnerByBib(widget.raceId, runner.bibNumber);
      }

      if (existingRunner != null) {
        // If we're updating the same runner (same ID), just update
        if ((widget.isTeam && existingRunner['runner_id'] == runner.runnerId) ||
            (!widget.isTeam && existingRunner['race_runner_id'] == runner.raceRunnerId)) {
          await _updateRunner(runner);
        } else {
          // If a different runner exists with this bib, ask for confirmation
          final shouldOverwrite = await DialogUtils.showConfirmationDialog(
            context,
            title: 'Overwrite Runner',
            content: 'A runner with bib number ${runner.bibNumber} already exists. Do you want to overwrite it?',
          );
          
          if (!shouldOverwrite) throw Exception('Cancelled by user');
          
          // Delete the existing runner and insert the new one
          if (widget.isTeam) {
            await DatabaseHelper.instance.deleteTeamRunner(runner.bibNumber);
          } else {
            await DatabaseHelper.instance.deleteRaceRunner(widget.raceId, runner.bibNumber);
          }
          await _insertRunner(runner);
        }
      } else {
        // No existing runner, just insert
        await _insertRunner(runner);
      }
      
      await _loadRunners();
    } catch (e) {
      throw Exception('Failed to save runner: $e');
    }
  }

  Future<void> _insertRunner(Runner runner) async {
    if (widget.isTeam) {
      await DatabaseHelper.instance.insertTeamRunner(runner.toMap());
    } else {
      final map = runner.toMap()..['race_id'] = widget.raceId;
      await DatabaseHelper.instance.insertRaceRunner(map);
    }
  }

  Future<void> _updateRunner(Runner runner) async {
    if (widget.isTeam) {
      await DatabaseHelper.instance.updateTeamRunner(runner.toMap());
    } else {
      final map = runner.toMap()..['race_id'] = widget.raceId;
      await DatabaseHelper.instance.updateRaceRunner(map);
    }
  }

  Future<void> _confirmDeleteAllRunners(BuildContext context) async {
    final confirmed = await DialogUtils.showConfirmationDialog(
      context,
      title: 'Confirm Deletion',
      content: 'Are you sure you want to delete all runners?',
    );
    
    if (!confirmed) return;
    
    if (widget.isTeam) {
      await DatabaseHelper.instance.clearTeamRunners();
    } else {
      await DatabaseHelper.instance.deleteAllRaceRunners(widget.raceId);
    }
    
    await _loadRunners();
  }

  Future<void> _showSampleSpreadsheet() async {
    final file = await rootBundle.loadString('assets/sample_sheets/sample_spreadsheet.csv');
    final lines = file.split('\n');
    final table = Table(
      border: TableBorder.all(color: Colors.grey),
      children: lines.map((line) {
        final cells = line.split(',');
        return TableRow(
          children: cells.map((cell) {
            return TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(cell),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
    await showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: table,
        ),
      ),
    );
    return;
  }

  Future<bool> _showSpreadsheetLoadSheet(BuildContext context) async {
    return await showModalBottomSheet(
      backgroundColor: AppColors.backgroundColor,
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            createSheetHandle(height: 10, width: 60),
            const SizedBox(height: 8),
            Text(
              'Load Runners from Spreadsheet',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async => await _showSampleSpreadsheet(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                fixedSize: const Size(175, 75),
              ),
              child: const Text('See Example', style: TextStyle(fontSize: 24)),  
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontSize: 24,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    fixedSize: const Size(175, 50),
                  ),
                  child: const Text('Load', style: TextStyle(fontSize: 24)),  
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSpreadsheetLoad() async {
    final confirmed = await _showSpreadsheetLoadSheet(context);
    if (!confirmed) return;
    final runnerData = await processSpreadsheet(widget.raceId, widget.isTeam);
    final overwriteRunners = [];
    for (final runner in runnerData) {
      dynamic existingRunner;
      if (widget.isTeam) {
        existingRunner = await DatabaseHelper.instance.getTeamRunnerByBib(runner['bib_number']);
      } else {
        existingRunner = await DatabaseHelper.instance.getRaceRunnerByBib(widget.raceId, runner['bib_number']);
      }
      if (existingRunner != null && runner['bib_number'] == existingRunner['bib_number'] && runner['name'] == existingRunner['name'] && runner['school'] == existingRunner['school'] && runner['grade'] == existingRunner['grade']) continue;

      if (existingRunner != null) {
        overwriteRunners.add(runner);
      }
      else {
        if (widget.isTeam) {
          await DatabaseHelper.instance.insertTeamRunner(runner);
        } else {
          await DatabaseHelper.instance.insertRaceRunner(runner);
        }
      }
    }
    await _loadRunners();
    if (overwriteRunners.isEmpty) return;
    final overwriteRunnersBibs = overwriteRunners.map((runner) => runner['bib_number']).toList();
    final overwriteExistingRunners = await DialogUtils.showConfirmationDialog(
      context,
      title: 'Confirm Overwrite',
      content: 'Are you sure you want to overwrite the following runners with bib numbers: ${overwriteRunnersBibs.join(', ')}?',
    );
    if (!overwriteExistingRunners) return;
    for (final runner in overwriteRunners) {
      if (widget.isTeam) {
        await DatabaseHelper.instance.deleteTeamRunner(runner['bib_number']);
        await DatabaseHelper.instance.insertTeamRunner(runner);
        print('Runner $runner overwritten');
      } else {
        await DatabaseHelper.instance.deleteRaceRunner(widget.raceId, runner['bib_number']);
        await DatabaseHelper.instance.insertRaceRunner(runner);
      }
    }
    await _loadRunners();
  }
}

class ActionIcon {
  final IconData icon;
  final Color backgroundColor;

  ActionIcon(this.icon, this.backgroundColor);
}