import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../models/runner.dart';

class ResolveBibNumberScreen extends StatefulWidget {
  final List<Map<String, dynamic>> records;
  final int raceId;
  
  const ResolveBibNumberScreen({
    super.key,
    required this.records,
    required this.raceId
  });

  @override
  State<ResolveBibNumberScreen> createState() => _ResolveBibNumberScreenState();
}

class _ResolveBibNumberScreenState extends State<ResolveBibNumberScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _errorRecords = [];
  int _currentIndex = 0;
  final _bibController = TextEditingController();
  final _nameController = TextEditingController();
  final _gradeController = TextEditingController();
  final _schoolController = TextEditingController();
  late int _raceId;
  
  @override
  void initState() {
    super.initState();
    _raceId = widget.raceId;
    _errorRecords = widget.records.where((record) => record['error'] != null).toList();
    if (_errorRecords.isNotEmpty) {
      _bibController.text = _errorRecords[0]['bib_number'].toString();
      // _nameController.text = _errorRecords[0]['name'];
      // _gradeController.text = _errorRecords[0]['grade'];
      // _schoolController.text = _errorRecords[0]['school'];
    }
  }

  Future<void> _createNewRunner() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for the runner')),
      );
      return;
    }

    final runner = Runner(
      name: _nameController.text,
      bibNumber: _bibController.text,
      raceId: _raceId,
      grade: _gradeController.text,
      school: _schoolController.text,
    );

    await _databaseHelper.insertRaceRunner(runner.toMap());
    _moveToNext();
  }

  Future<void> _updateBibNumber() async {
    final newBibNumber = _bibController.text;
    final existingRunner = await _databaseHelper.getRaceRunnerByBib(_raceId, newBibNumber);
    
    if (existingRunner == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No runner found with this bib number')),
      );
      return;
    }

    _errorRecords[_currentIndex]['bib_number'] = newBibNumber;
    _errorRecords[_currentIndex]['error'] = null;
    _moveToNext();
  }

  void _moveToNext() {
    if (_currentIndex < _errorRecords.length - 1) {
      setState(() {
        _currentIndex++;
        _bibController.text = _errorRecords[_currentIndex]['bib_number'].toString();
        _nameController.clear();
        _gradeController.clear();
        _schoolController.clear();
      });
    } else {
      Navigator.pop(context, widget.records);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorRecords.isEmpty) {
      return const Center(child: Text('No records to resolve'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resolve Bib Numbers'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Record ${_currentIndex + 1} of ${_errorRecords.length}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text('Error: ${_errorRecords[_currentIndex]['error']}'),
            const SizedBox(height: 24),
            TextField(
              controller: _bibController,
              decoration: const InputDecoration(
                labelText: 'Bib Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _updateBibNumber,
              child: const Text('Update Bib Number'),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Runner Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _gradeController,
              decoration: const InputDecoration(
                labelText: 'Grade',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _schoolController,
              decoration: const InputDecoration(
                labelText: 'School',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _createNewRunner,
              child: const Text('Create New Runner'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bibController.dispose();
    _nameController.dispose();
    _gradeController.dispose();
    _schoolController.dispose();
    super.dispose();
  }
}