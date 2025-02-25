import 'package:flutter/material.dart';
import '../utils/time_formatter.dart';
import 'dart:math';
import '../database_helper.dart';
import 'results_screen.dart';
import '../utils/app_colors.dart';
import '../utils/dialog_utils.dart';
import '../runner_time_functions.dart';
import '../utils/typography.dart';

class EditAndReviewScreen extends StatefulWidget {
  final Map<String, dynamic> timingData;
  final int raceId;

  const EditAndReviewScreen({
    super.key, 
    required this.timingData,
    required this.raceId,
  });

  @override
  State<EditAndReviewScreen> createState() => _EditAndReviewScreenState();
}

class _EditAndReviewScreenState extends State<EditAndReviewScreen> {
  // State variables
  late final ScrollController _scrollController;
  late final Map<int, TextEditingController> _finishTimeControllers;
  late final List<TextEditingController> _controllers;
  late final Map<String, dynamic> _timingData;
  late final int _raceId;

  @override
  void initState() {
    super.initState();
    _initializeState();
  }

  void _initializeState() {
    _scrollController = ScrollController();
    _timingData = widget.timingData;
    _raceId = widget.raceId;
    _finishTimeControllers = _initializeFinishTimeControllers();
    _controllers = List.generate(getNumberOfTimes(_timingData['records'] ?? []), (index) => TextEditingController());
    // _fetchRunners();
  }

  Map<int, TextEditingController> _initializeFinishTimeControllers() {
    final controllers = <int, TextEditingController>{};
    for (var record in _timingData['records']) {
      if (record['type'] == 'runner_time' && record['conflict'] == null) {
        controllers[record['place']] = TextEditingController(text: record['finish_time']);
      }
    }
    return controllers;
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
  }


  Future<void> _saveResults() async {
    final records = _timingData['records'] ?? [];
    if (!_validateRunnerInfo(records)) {
      DialogUtils.showErrorDialog(context, message: 'All runners must have a bib number assigned before proceeding.');
      return;
    }

    await _processAndSaveRecords(records);
    _showResultsSavedSnackBar();
  }

  bool _validateRunnerInfo(List<dynamic> records) {
    return records.every((runner) => 
      runner['bib_number'] != null && 
      runner['name'] != null && 
      runner['grade'] != null && 
      runner['school'] != null
    );
  }

  Future<void> _processAndSaveRecords(List<dynamic> records) async {
    final processedRecords = records.where((record) => record['type'] == 'runner_time').map((record) {
      final cleanRecord = Map<String, dynamic>.from(record);
      ['bib_number', 'name', 'grade', 'school', 'text_color', 'is_confirmed', 
       'type', 'conflict'].forEach(cleanRecord.remove);
      return cleanRecord;
    }).toList();

    await DatabaseHelper.instance.insertRaceResults(processedRecords);
  }

  void _showResultsSavedSnackBar() {
    _navigateToResultsScreen();
    DialogUtils.showSuccessDialog(context, message: 'Results saved successfully. View results?');
  }

  void _navigateToResultsScreen() {
    DialogUtils.showErrorDialog(context, message: 'Results saved successfully. Results screen not yet implemented.');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultsScreen(raceId: _raceId),
      ),
    );
  }

  bool _timeIsValid(String newValue, int index, List<dynamic> timeRecords) {
    Duration? parsedTime = loadDurationFromString(newValue);
    if (parsedTime == null || parsedTime < Duration.zero) {
      DialogUtils.showErrorDialog(context, message: 'Invalid time entered. Should be in HH:mm:ss.ms format');
      return false;
    }

    if (index < 0 || index >= timeRecords.length) {
      return false;
    }

    if (index > 0 && loadDurationFromString(timeRecords[index - 1]['finish_time'])! > parsedTime) {
      DialogUtils.showErrorDialog(context, message: 'Time must be greater than the previous time');
      return false;
    }

    if (index < timeRecords.length - 1 && loadDurationFromString(timeRecords[index + 1]['finish_time'])! < parsedTime) {
      DialogUtils.showErrorDialog(context, message: 'Time must be less than the next time');
      return false;
    }

    return true;
  }

  int getRunnerIndex(int recordIndex) {
    final records = _timingData['records'] ?? [];
    final runnerRecords = records.where((record) => record['type'] == 'runner_time').toList();
    return runnerRecords.indexOf(records[recordIndex]);
  }

  Future<bool> _confirmDeleteLastRecord(int recordIndex) async {
    final records = _timingData['records'] ?? [];
    final record = records[recordIndex];
    if (record['type'] == 'runner_time' && record['is_confirmed'] == false && record['conflict'] == null) {
      return await DialogUtils.showConfirmationDialog(context, title: 'Confirm Deletion', content: 'Are you sure you want to delete this runner?');
    }
    return false;
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (var controller in _finishTimeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startTime = _timingData['startTime'];
    final timeRecords = _timingData['records'] ?? [];

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 30),
            Text(
              'Review Results',
              style: AppTypography.titleSemibold,
            ),
            const SizedBox(height: 8),
            Text(
              'Please review and edit the results before saving:',
              style: AppTypography.bodyRegular,
            ),
            const SizedBox(height: 16),
            _buildControlButtons(startTime, timeRecords),
            _buildRecordsList(timeRecords),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons(DateTime? startTime, List<dynamic> timeRecords) {
    if (startTime != null || timeRecords.isEmpty) return const SizedBox.shrink();
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionButton('Save Results', _saveResults),
      ],
    );
  }

  Widget _buildActionButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: 330,
      height: 100,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
              ),
              child: Text(
                text,
                style: TextStyle(fontSize: constraints.maxWidth * 0.12, color: AppColors.unselectedRoleColor),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecordsList(List<dynamic> timeRecords) {
    if (timeRecords.isEmpty) return const Expanded(child: SizedBox.shrink());

    return Expanded(
      child: Column(
        children: [
          _buildDivider(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: timeRecords.length,
              itemBuilder: (context, index) => _buildRecordItem(context, index, timeRecords),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(BuildContext context, int index, List<dynamic> timeRecords) {
    final timeRecord = timeRecords[index];
    if (_finishTimeControllers[index] == null) {
      _finishTimeControllers[index] = TextEditingController(text: timeRecord['finish_time']);
    }

    switch (timeRecord['type']) {
      case 'runner_time':
        return _buildRunnerTimeRecord(context, index, timeRecord);
      case 'confirm_runner_number':
        return _buildConfirmationRecord(context, index, timeRecord);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildConfirmationRecord(BuildContext context, int index, Map<String, dynamic> timeRecord) {
    final isLastRecord = index == _timingData['records'].length - 1;
    
    return Container(
      margin: EdgeInsets.fromLTRB(
        MediaQuery.of(context).size.width * 0.02,
        MediaQuery.of(context).size.width * 0.01,
        MediaQuery.of(context).size.width * 0.02,
        MediaQuery.of(context).size.width * 0.02,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: isLastRecord 
              ? () => _handleConfirmationDeletion(index)
              : null,
            child: Text(
              'Confirmed: ${timeRecord['finish_time']}',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width * 0.05,
                fontWeight: FontWeight.bold,
                color: AppColors.darkColor,
              ),
            ),
          ),
          _buildDivider(),
        ],
      ),
    );
  }

  _handleConfirmationDeletion(int index) async {
    setState(() {
      _timingData['records'].removeAt(index);
      _timingData['records'] = updateTextColor(null, _timingData['records']);
    });
  }

  Widget _buildRunnerInfoRow(
    BuildContext context, 
    Map<String, dynamic> timeRecord, 
    int index
  ) {
    final textStyle = TextStyle(
      fontSize: MediaQuery.of(context).size.width * 0.05,
      fontWeight: FontWeight.bold,
      color: timeRecord['text_color'] ?? AppColors.navBarTextColor,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Place number
        Text(
          '${timeRecord['place']}',
          style: textStyle.copyWith(
            color: AppColors.darkColor,
          ),
        ),

        // Runner information
        Text(
          _formatRunnerInfo(timeRecord),
          style: textStyle,
        ),

        // Finish time input
        if (timeRecord['finish_time'] != null)
          _buildFinishTimeField(timeRecord, index, textStyle),
      ],
    );
  }

  String _formatRunnerInfo(Map<String, dynamic> record) {
    return [
      if (record['name'] != null) record['name'],
      if (record['grade'] != null) ' ${record['grade']}',
      if (record['school'] != null) ' ${record['school']}    ',
    ].join();
  }

  Widget _buildFinishTimeField(
    Map<String, dynamic> timeRecord, 
    int index,
    TextStyle textStyle
  ) {
    final isEnabled = timeRecord['finish_time'] != 'tbd' && 
                     timeRecord['finish_time'] != 'TBD';

    return SizedBox(
      width: 100,
      child: TextField(
        controller: _finishTimeControllers[index],
        decoration: InputDecoration(
          hintText: 'Finish Time',
          border: OutlineInputBorder(
            borderSide: BorderSide(
              color: AppColors.darkColor,
            ),
          ),
          hintStyle: TextStyle(
            color: AppColors.darkColor,
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(
              color: AppColors.primaryColor,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: AppColors.darkColor,
            ),
          ),
          disabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(
              color: Colors.transparent,
            ),
          ),
        ),
        style: TextStyle(
          color: AppColors.darkColor,
        ),
        enabled: isEnabled,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(
          signed: true, 
          decimal: false
        ),
        onSubmitted: (newValue) => _handleTimeSubmission(newValue, index, timeRecord),
      ),
    );
  }

  void _handleTimeSubmission(String newValue, int index, Map<String, dynamic> timeRecord) {
    if (newValue.isNotEmpty && _timeIsValid(newValue, index, _timingData['records'])) {
      timeRecord['finish_time'] = newValue;
    } else {
      // Reset to previous value
      _finishTimeControllers[index]?.text = timeRecord['finish_time'];
    }
  }

  Widget _buildRunnerTimeRecord(BuildContext context, int index, Map<String, dynamic> timeRecord) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        MediaQuery.of(context).size.width * 0.02,
        0,
        MediaQuery.of(context).size.width * 0.01,
        MediaQuery.of(context).size.width * 0.02,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () async {
              final confirmed = await _confirmDeleteLastRecord(index);
              if (confirmed ) {
                setState(() {
                  _controllers.removeAt(getNumberOfTimes(_timingData['records'] ?? []) - 1);
                  _timingData['records']?.removeAt(index);
                  _scrollController.animateTo(
                    max(_scrollController.position.maxScrollExtent, 0),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                });
              }
            },
            child: _buildRunnerInfoRow(context, timeRecord, index),
          ),
          _buildDivider(),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      thickness: 1,
      color: Color.fromRGBO(128, 128, 128, 0.5),
    );
  }
}
