import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../models/runner.dart';
import '../utils/app_colors.dart';
import '../utils/dialog_utils.dart';

class ResolveBibNumberScreen extends StatefulWidget {
  final List<Map<String, dynamic>> records;
  final int raceId;
  final Function(List<Map<String, dynamic>>) onComplete;
  
  const ResolveBibNumberScreen({
    super.key,
    required this.records,
    required this.raceId,
    required this.onComplete,
  });

  @override
  State<ResolveBibNumberScreen> createState() => _ResolveBibNumberScreenState();
}

class _ResolveBibNumberScreenState extends State<ResolveBibNumberScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _errorRecords = [];
  List<Map<String, dynamic>> _searchResults = [];
  int _currentIndex = 0;
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _gradeController = TextEditingController();
  final _schoolController = TextEditingController();
  bool _showCreateNew = false;
  late int _raceId;
  late List<Map<String, dynamic>> _records;
  String _currentBibNumber = '';
  
  @override
  void initState() {
    super.initState();
    _raceId = widget.raceId;
    _records = widget.records;
    _errorRecords = _records.where((record) => record['error'] != null).toList();
    if (_errorRecords.isNotEmpty) {
      _currentBibNumber = _errorRecords[0]['bib_number'].toString();
      _searchRunners('');
    }
  }

  Future<void> _searchRunners(String query) async {
    if (query.isEmpty) {
      final results = await _databaseHelper.getRaceRunners(_raceId);
      setState(() {
        _searchResults = results;
      });
      return;
    }

    final results = await _databaseHelper.searchRaceRunners(_raceId, query);
    setState(() {
      _searchResults = results;
    });
  }

  Future<void> _createNewRunner() async {
    if (_nameController.text.isEmpty || _gradeController.text.isEmpty || _schoolController.text.isEmpty) {
      DialogUtils.showErrorDialog(context, message: 'Please enter a name, grade, and school for the runner');
      return;
    }

    final runner = Runner(
      name: _nameController.text,
      bibNumber: _currentBibNumber,
      raceId: _raceId,
      grade: _gradeController.text,
      school: _schoolController.text,
    );

    await _databaseHelper.insertRaceRunner(runner.toMap());
    _errorRecords[_currentIndex]['error'] = null;
    await _moveToNext();
  }

  Future<void> _assignExistingRunner(Map<String, dynamic> runner) async {
    if (_records.any((record) => record['bib_number'] == runner['bib_number'])) {
      DialogUtils.showErrorDialog(context, message: 'This bib number is already assigned to another runner');
      return;
    }
    final confirmed = await DialogUtils.showConfirmationDialog(context, title: 'Assign Runner', content: 'Are you sure this is the correct runner? \nName: ${runner['name']} \nGrade: ${runner['grade']} \nSchool: ${runner['school']} \nBib Number: ${runner['bib_number']}');
    if (!confirmed) return;
    _errorRecords[_currentIndex]['bib_number'] = runner['bib_number'];
    _errorRecords[_currentIndex]['error'] = null;
    await _moveToNext();
  }

  Future<void> _moveToNext() async {
    if (_currentIndex < _errorRecords.length - 1) {
      final runners = await _databaseHelper.getRaceRunners(_raceId);
      setState(() {
        _currentIndex++;
        _currentBibNumber = _errorRecords[_currentIndex]['bib_number'].toString();
        _searchController.clear();
        _nameController.clear();
        _gradeController.clear();
        _schoolController.clear();
        _searchResults = runners;
        _showCreateNew = false;
      });
    } else {
      widget.onComplete(widget.records);
    }
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
                  runner['name'] ?? '',
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
                          'Bib ${runner['bib_number']}',
                          AppColors.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        if (runner['grade'] != null)
                          _buildInfoChip(
                            'Grade ${runner['grade']}',
                            AppColors.mediumColor,
                          ),
                        const SizedBox(width: 8),
                        if (runner['school'] != null)
                          Expanded(
                            child: _buildInfoChip(
                              runner['school'],
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
    if (_errorRecords.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No records to resolve')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resolve Bib Numbers'),
        elevation: 0,
        backgroundColor: AppColors.primaryColor,
      ),
      body: Container(
        color: AppColors.backgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
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
                child: Column(
                  children: [
                    Text(
                      'Unknown Bib Number ${_currentIndex + 1} of ${_errorRecords.length}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A runner with bib number $_currentBibNumber does not exist',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
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

  Widget _buildActionButton(String label, IconData icon, bool isSelected, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? AppColors.primaryColor : Colors.grey[300],
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: isSelected ? 3 : 1,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey[700]),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                maxLines: null,
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