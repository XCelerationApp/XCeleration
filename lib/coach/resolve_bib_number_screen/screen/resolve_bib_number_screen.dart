import 'package:flutter/material.dart';
import '../../../utils/database_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/components/dialog_utils.dart';
import '../../race_screen/widgets/runner_record.dart';
import '../../../core/components/instruction_card.dart';

class ResolveBibNumberScreen extends StatefulWidget {
  final List<RunnerRecord> records;
  final int raceId;
  final Function(RunnerRecord) onComplete;
  final RunnerRecord record;
  
  const ResolveBibNumberScreen({
    super.key,
    required this.records,
    required this.raceId,
    required this.onComplete,
    required this.record,
  });

  @override
  State<ResolveBibNumberScreen> createState() => _ResolveBibNumberScreenState();
}

class _ResolveBibNumberScreenState extends State<ResolveBibNumberScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  // List<RunnerRecord> _errorRecords = [];
  List<RunnerRecord> _searchResults = [];
  // int _currentIndex = 0;
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _gradeController = TextEditingController();
  final _schoolController = TextEditingController();
  bool _showCreateNew = false;
  late int _raceId;
  late List<RunnerRecord> _records;
  // String _currentBibNumber = '';
  late RunnerRecord _record;
  
  @override
  void initState() {
    super.initState();
    _raceId = widget.raceId;
    _records = widget.records;
    // _errorRecords = _records.where((record) => record.error != null).toList();
    // if (_errorRecords.isNotEmpty) {
    //   _currentBibNumber = _errorRecords[0].bib.toString();
    _record = widget.record;
    _searchRunners('');
    // }
  }

  Future<void> _searchRunners(String query) async {
    print('Searching runners...');
    print('Query: $query');
    print('Race ID: $_raceId');
    if (query.isEmpty) {
      final results = await _databaseHelper.getRaceRunners(_raceId);
      setState(() {
        _searchResults = results;
      });
      print('Search results: ${_searchResults.map((r) => r.bib).join(', ')}');
      return;
    }

    final results = await _databaseHelper.searchRaceRunners(_raceId, query);
    setState(() {
      _searchResults = results;
    });
    print('Search results: ${_searchResults.map((r) => r.bib).join(', ')}');
  }

  Future<void> _createNewRunner() async {
    if (_nameController.text.isEmpty || _gradeController.text.isEmpty || _schoolController.text.isEmpty) {
      DialogUtils.showErrorDialog(context, message: 'Please enter a name, grade, and school for the runner');
      return;
    }

    final runner = RunnerRecord(
      name: _nameController.text,
      bib: _record.bib,
      raceId: _raceId,
      grade: int.parse(_gradeController.text),
      school: _schoolController.text,
    );

    await _databaseHelper.insertRaceRunner(runner);
    _record.error = null;
    
    // Update the current record with the new runner information
    _record.name = runner.name;
    _record.grade = runner.grade;
    _record.school = runner.school;
    
    // Return the updated records immediately
    widget.onComplete(_record);
  }

  Future<void> _assignExistingRunner(RunnerRecord runner) async {
    if (_records.any((record) => record.bib == runner.bib && record != _record)) {
      DialogUtils.showErrorDialog(context, message: 'This bib number is already assigned to another runner');
      return;
    }
    final confirmed = await DialogUtils.showConfirmationDialog(context, title: 'Assign Runner', content: 'Are you sure this is the correct runner? \nName: ${runner.name} \nGrade: ${runner.grade} \nSchool: ${runner.school} \nBib Number: ${runner.bib}');
    if (!confirmed) return;
    
    // Update all fields from the selected runner
    _record.bib = runner.bib;
    _record.error = null;
    _record.name = runner.name;
    _record.grade = runner.grade;
    _record.school = runner.school;
    _record.runnerId = runner.runnerId;
    _record.flags = runner.flags;
    _record.raceId = runner.raceId;

    // Return the updated records immediately
    widget.onComplete(_record);
  }

  Widget _buildSearchResults() {
    return Expanded(
      child: ListView.builder(
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final runner = _searchResults[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: AppColors.primaryColor.withAlpha((0.2 * 255).round()),
                  width: 1,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  runner.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildInfoChip(
                          'Bib ${runner.bib}',
                          AppColors.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        if (runner.grade > 0)
                          _buildInfoChip(
                            'Grade ${runner.grade}',
                            AppColors.mediumColor,
                          ),
                        const SizedBox(width: 8),
                        if (runner.school != '')
                          Expanded(
                            child: _buildInfoChip(
                              runner.school,
                              AppColors.mediumColor,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                onTap: () => _assignExistingRunner(runner),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withAlpha((0.2 * 255).round()),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildCreateNewForm() {
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(
              controller: _nameController,
              label: 'Runner Name',
              icon: Icons.person,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _gradeController,
              label: 'Grade',
              icon: Icons.school,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _schoolController,
              label: 'School',
              icon: Icons.business,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _createNewRunner,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
              ),
              child: const Text(
                'Create New Runner',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    Future<void> Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.primaryColor.withAlpha((0.2 * 255).round()),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.primaryColor.withAlpha((0.2 * 255).round()),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.primaryColor,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_record.error == null) {
      return const Scaffold(
        body: Center(child: Text('No records to resolve')),
      );
    }

    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Resolve Bib Numbers'),
      //   elevation: 0,
      //   backgroundColor: AppColors.primaryColor,
      // ),
      body: Container(
        color: AppColors.backgroundColor,
        child: Padding(
          // padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          padding: EdgeInsets.all(0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInstructionsCard(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      'Choose Existing Runner',
                      Icons.people,
                      !_showCreateNew,
                      () {
                        setState(() {
                          _showCreateNew = false;
                          _searchRunners(_searchController.text);
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionButton(
                      'Create New Runner',
                      Icons.person_add,
                      _showCreateNew,
                      () {
                        setState(() {
                          _showCreateNew = true;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (!_showCreateNew) ...[
                _buildTextField(
                  controller: _searchController,
                  label: 'Search runners',
                  icon: Icons.search,
                  onChanged: (value) => _searchRunners(value),
                ),
                const SizedBox(height: 16),
                _buildSearchResults(),
              ] else _buildCreateNewForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return InstructionCard(
      title: 'Resolve Bib Number',
      instructions: [
        InstructionItem(number: '1', text: 'Choose an existing runner or create a new one to assign to bib #${_record.bib}'),
        const InstructionItem(number: '2', text: 'For existing runners, search by name, school, or bib number'),
        const InstructionItem(number: '3', text: 'For new runners, enter all required information'),
      ],
      initiallyExpanded: true,
    );
  }

  Widget _buildActionButton(String label, IconData icon, bool isSelected, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? AppColors.primaryColor : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: AppColors.primaryColor.withAlpha((0.2 * 255).round()),
            width: 1,
          ),
        ),
        elevation: isSelected ? 3 : 1,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : AppColors.primaryColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                maxLines: null,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _gradeController.dispose();
    _schoolController.dispose();
    super.dispose();
  }
}