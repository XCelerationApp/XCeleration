import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/dialog_utils.dart';
import 'package:race_timing_app/database_helper.dart';
import 'package:race_timing_app/file_processing.dart';

// Models
class Team {
  final String name;
  final Color color;

  Team({required this.name, required this.color});
}

class _FormControllers {
  final name = TextEditingController();
  final grade = TextEditingController();
  final school = TextEditingController();
  final bib = TextEditingController();

  void dispose() {
    name.dispose();
    grade.dispose();
    school.dispose();
    bib.dispose();
  }

  void clear() {
    name.clear();
    grade.clear();
    school.clear();
    bib.clear();
  }
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
}

// Components
class RunnerTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isNumeric;
  final String? initialValue;

  const RunnerTextField({
    Key? key,
    required this.controller,
    required this.label,
    this.isNumeric = false,
    this.initialValue,
  }) : super(key: key);

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

class RunnerListItem extends StatelessWidget {
  final Runner runner;
  final Function(String) onActionSelected;
  final List<Team> teamData;

  const RunnerListItem({
    Key? key,
    required this.runner,
    required this.onActionSelected,
    required this.teamData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final team = teamData.firstWhereOrNull((team) => team.name == runner.school);
    final bibColor = team != null ? team.color : AppColors.mediumColor;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: bibColor.withOpacity(0.1),
            ),
            child: Row(
              children: [
                // CircleAvatar(
                //   backgroundColor: bibColor,
                SizedBox(width: 8),
                  Text(
                    runner.bibNumber,
                    style: TextStyle(
                      // color: bibColor.computeLuminance() > 0.5 ? AppColors.unselectedRoleTextColor : Colors.white,
                      color: bibColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                // ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Text(
                    runner.name,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                Expanded(
                  child: Text(
                    runner.grade.toString(),
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
                Expanded(
                  child: Text(
                    runner.school,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: onActionSelected,
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'Edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'Delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Colors.grey),
      ],
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
    Key? key,
    required this.controller,
    required this.searchAttribute,
    required this.onSearchChanged,
    required this.onAttributeChanged,
    required this.onDeleteAll,
  }) : super(key: key);

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
          child: DropdownButton<String>(
            value: searchAttribute,
            onChanged: onAttributeChanged,
            items: ['Bib Number', 'Name', 'Grade', 'School']
                .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                .toList(),
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
    Key? key,
    required this.raceId,
    required this.isTeam,
  }) : super(key: key);

  @override
  State<RunnersManagementScreen> createState() => _RunnersManagementScreenState();
}

class _RunnersManagementScreenState extends State<RunnersManagementScreen> {
  final _formControllers = _FormControllers();
  final _searchController = TextEditingController();
  String _searchAttribute = 'Bib Number';
  
  List<Runner> _runners = [];
  List<Runner> _filteredRunners = [];
  List<Team> _teams = [];

  @override
  void initState() {
    super.initState();
    _loadRunners();
    _loadTeams();
  }

  @override
  void dispose() {
    _formControllers.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTeams() async {
    final race = await DatabaseHelper.instance.getRaceById(widget.raceId);
    for (var i = 0; i < race!.teams.length; i++) {
      final Color teamColor = race.teamColors[i];
      final String teamName = race.teams[i];
      _teams.add(Team(name: teamName, color: teamColor));
      print(_teams);
    }
    setState(() {});
  }

  Future<void> _loadRunners() async {
    final runners = widget.isTeam
        ? await DatabaseHelper.instance.getAllTeamRunners()
        : await DatabaseHelper.instance.getRaceRunners(widget.raceId);
    setState(() {
      _runners = runners.map(Runner.fromMap).toList();
      _sortRunners();
      _filteredRunners = _runners;
    });
  }

  void _sortRunners() {
    _runners.sort((a, b) {
      if (int.parse(a.bibNumber) == int.parse(b.bibNumber)) {
        return a.bibNumber.compareTo(b.bibNumber);
      } else {
        return int.parse(a.bibNumber).compareTo(int.parse(b.bibNumber));
      }
    });
  }

  void _filterRunners(String query) {
    if (query.isEmpty) {
      setState(() => _filteredRunners = _runners);
      return;
    }

    setState(() {
      _filteredRunners = _runners.where((runner) {
        final value = switch (_searchAttribute) {
          'Bib Number' => runner.bibNumber,
          'Name' => runner.name.toLowerCase(),
          'Grade' => runner.grade.toString(),
          'School' => runner.school.toLowerCase(),
          _ => ''
        };
        final searchTerm = _searchAttribute == 'Name' || _searchAttribute == 'School'
            ? query.toLowerCase()
            : query;
        return value.contains(searchTerm);
      }).toList();
    });
  }

  Future<void> _handleRunnerAction(String action, Runner runner) async {
    switch (action) {
      case 'Edit':
        await _showRunnerDialog(
          context: context,
          title: 'Edit Runner',
          runner: runner,
        );
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Text('Bib Number', style: TextStyle(fontWeight: FontWeight.bold)),
        Text('Name', style: TextStyle(fontWeight: FontWeight.bold)),
        Text('Grade', style: TextStyle(fontWeight: FontWeight.bold)),
        Text('School', style: TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
      ),
    );
  }


  // UI Building Methods
  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          'Add Runner',
          onPressed: () => _showRunnerDialog(context: context, title: 'Add Runner'),
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
    if (_filteredRunners.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty
              ? (widget.isTeam ? 'No Runners' : 'No Runners for this race')
              : 'No Runners found',
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
            )).toList(),
          ],
        );
      },
    );
  }

  // Dialog and Action Methods
  Future<void> _showRunnerDialog({
    required BuildContext context,
    required String title,
    Runner? runner,
  }) async {
    if (runner != null) {
      _formControllers.name.text = runner.name;
      _formControllers.grade.text = runner.grade.toString();
      _formControllers.school.text = runner.school;
      _formControllers.bib.text = runner.bibNumber;
    }

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RunnerTextField(controller: _formControllers.name, label: 'Full Name'),
              RunnerTextField(controller: _formControllers.grade, label: 'Grade', isNumeric: true),
              RunnerTextField(controller: _formControllers.school, label: 'School'),
              RunnerTextField(controller: _formControllers.bib, label: 'Bib Number', isNumeric: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _handleRunnerSubmission(runner),
            child: Text(runner == null ? 'Add' : 'Edit'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRunnerSubmission(Runner? existingRunner) async {
    final name = _formControllers.name.text;
    final grade = int.tryParse(_formControllers.grade.text);
    final school = _formControllers.school.text;
    final bib = _formControllers.bib.text;

    if (name.isEmpty || grade == null || school.isEmpty || bib.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }
    Map<String, dynamic>? duplicateRunner;
    String? duplicateBib;
    if (widget.isTeam) {
      duplicateRunner = await DatabaseHelper.instance.getTeamRunnerByBib(bib);
      duplicateBib = duplicateRunner?['bib_number'];
    } else {
      duplicateRunner = (await DatabaseHelper.instance.getRaceRunnerByBib(widget.raceId, bib))[0];
      duplicateBib = duplicateRunner?['bib_number'];
    }
    if (duplicateBib != null) {
      final shouldOverwrite = await DialogUtils.showConfirmationDialog(context, title: 'Overwrite Runner', content:'A runner with bib number $duplicateBib already exists. Do you want to overwrite the existing runner instead?');
      if (!shouldOverwrite) return;
      if (widget.isTeam) {
        await DatabaseHelper.instance.deleteTeamRunner(duplicateBib);
      } else {
        await DatabaseHelper.instance.deleteRaceRunner(widget.raceId, duplicateBib);
      }
    }

    final runner = Runner(
      name: name,
      grade: grade,
      school: school,
      bibNumber: bib,
      runnerId: existingRunner?.runnerId,
      raceRunnerId: existingRunner?.raceRunnerId,
    );

    if (existingRunner == null) {
      await _addRunner(runner);
    } else {
      await _updateRunner(runner);
    }

    _formControllers.clear();
    await _loadRunners();
    Navigator.of(context).pop();
  }

  Future<void> _addRunner(Runner runner) async {
    if (widget.isTeam) {
      await DatabaseHelper.instance.insertTeamRunner(runner.toMap());
    } else {
      final map = runner.toMap()..['race_id'] = widget.raceId;
      await DatabaseHelper.instance.insertRaceRunner(map);
    }
  }

  Future<void> _updateRunner(Runner runner) async {
    if (widget.isTeam) {
      await DatabaseHelper.instance.updateTeamRunner({
        'name': runner.name,
        'school': runner.school,
        'grade': runner.grade,
        'bib_number': runner.bibNumber,
        'runner_id': runner.runnerId,
      });
    } else {
      await DatabaseHelper.instance.updateRaceRunner({
        'name': runner.name,
        'school': runner.school,
        'grade': runner.grade,
        'bib_number': runner.bibNumber,
        'race_runner_id': runner.raceRunnerId,
      });
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

  Future<void> _handleSpreadsheetLoad() async {
    final runnerData = await processSpreadsheet(widget.raceId, widget.isTeam);
    final overwriteRunners = [];
    for (final runner in runnerData) {
      dynamic existingRunner;
      if (widget.isTeam) {
        existingRunner = await DatabaseHelper.instance.getTeamRunnerByBib(runner['bib_number']);
      } else {
        existingRunner = (await DatabaseHelper.instance.getRaceRunnerByBib(widget.raceId, runner['bib_number']))[0];
      }
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