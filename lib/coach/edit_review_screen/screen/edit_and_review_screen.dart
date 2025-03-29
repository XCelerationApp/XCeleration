import 'dart:math';

import 'package:flutter/material.dart';
import 'package:xcelerate/assistant/race_timer/model/timing_record.dart';
import 'package:xcelerate/coach/merge_conflicts/model/timing_data.dart';
// import 'package:xcelerate/coach/race_screen/model/race_result.dart';
import 'package:xcelerate/utils/database_helper.dart';
import 'package:xcelerate/utils/enums.dart';
import '../../../../utils/time_formatter.dart';
import '../../results_screen/screen/results_screen.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../core/components/dialog_utils.dart';
import '../../../../utils/runner_time_functions.dart';
import '../../../../core/theme/typography.dart';


class EditAndReviewScreen extends StatefulWidget {
  final TimingData timingData;
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
  late final TimingData _timingData;
  late final int _raceId;

  @override
  void initState() {
    super.initState();
    _initializeState();
    _scrollController = ScrollController();
  }

  void _initializeState() {
    _timingData = widget.timingData;
    _raceId = widget.raceId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _saveResults() async {
    final records = _timingData.records;
    if (!_validateRunnerInfo(records)) {
      DialogUtils.showErrorDialog(context, message: 'All runners must have a bib number assigned before proceeding.');
      return;
    }

    await _processAndSaveRecords(records);
    _showResultsSavedSnackBar();
  }

  bool _validateRunnerInfo(List<TimingRecord> records) {
    return records.every((runner) => 
      runner.bib != '' && 
      runner.name != '' && 
      runner.grade != null &&
      runner.grade! > 0 && 
      runner.school != ''
    );
  }

  Future<void> _processAndSaveRecords(List<TimingRecord> records) async {
    final processedRecords = _timingData.raceResults;

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

  bool _timeIsValid(String newValue, int index, List<TimingRecord> timeRecords) {
    Duration? parsedTime = loadDurationFromString(newValue);
    if (parsedTime == null || parsedTime < Duration.zero) {
      DialogUtils.showErrorDialog(context, message: 'Invalid time entered. Should be in HH:mm:ss.ms format');
      return false;
    }

    if (index < 0 || index >= timeRecords.length) {
      return false;
    }

    if (index > 0 && loadDurationFromString(timeRecords[index - 1].elapsedTime)! > parsedTime) {
      DialogUtils.showErrorDialog(context, message: 'Time must be greater than the previous time');
      return false;
    }

    if (index < timeRecords.length - 1 && loadDurationFromString(timeRecords[index + 1].elapsedTime)! < parsedTime) {
      DialogUtils.showErrorDialog(context, message: 'Time must be less than the next time');
      return false;
    }

    return true;
  }

  int getRunnerIndex(int recordIndex) {
    final records = _timingData.records;
    final runnerRecords = records.where((r) => r.type == RecordType.runnerTime).toList();
    return runnerRecords.indexOf(records[recordIndex]);
  }


  Future<bool> _confirmDeleteLastRecord(int recordIndex) async {
    final records = _timingData.records;
    final record = records[recordIndex];
    if (record.type == RecordType.runnerTime && !record.isConfirmed && record.conflict == null) {
      return await DialogUtils.showConfirmationDialog(context, title: 'Confirm Deletion', content: 'Are you sure you want to delete this runner?');
    }
    return false;
  }


  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startTime = _timingData.startTime;
    final timeRecords = _timingData.records;

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

  Widget _buildRecordsList(List<TimingRecord> timeRecords) {
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

  Widget _buildRecordItem(BuildContext context, int index, List<TimingRecord> timeRecords) {
    final record = timeRecords[index];
    // Convert TimingRecord to map for easier access
    // final Map<String, dynamic> recordMap = record.toMap();

    if (record.type == RecordType.confirmRunner) {
      return _buildConfirmationRecord(context, index, record);
    } else if (record.type == RecordType.runnerTime) {
      return _buildRunnerTimeRecord(context, index, record);
    }
    return const SizedBox.shrink();
  }

  Widget _buildConfirmationRecord(BuildContext context, int index, TimingRecord timeRecord) {
    final isLastRecord = index == _timingData.records.length - 1;
    
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
              'Confirmed: ${timeRecord.elapsedTime}',
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
      _timingData.records.removeAt(index);
      _timingData.records = updateTextColor(null, _timingData.records);
    });
  }

  Widget _buildRunnerInfoRow(
    BuildContext context, 
    TimingRecord timeRecord, 
    int index
  ) {
    final textStyle = TextStyle(
      fontSize: MediaQuery.of(context).size.width * 0.05,
      fontWeight: FontWeight.bold,
      color: timeRecord.textColor ?? AppColors.navBarTextColor,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Place number
        Text(
          'Time: ${timeRecord.elapsedTime}',
          style: textStyle,
        ),

        // Runner information
        Text(
          _formatRunnerInfo(timeRecord),
          style: textStyle,
        ),

        // Finish time input
        if (timeRecord.elapsedTime != '')
          _buildFinishTimeField(timeRecord, index, textStyle),
      ],
    );
  }

  String _formatRunnerInfo(TimingRecord record) {
    return [
      if (record.name != null) record.name,
      if (record.grade != null) ' ${record.grade}',
      if (record.school != null) ' ${record.school}    ',
    ].join();
  }

  Widget _buildFinishTimeField(
    TimingRecord timeRecord, 
    int index,
    TextStyle textStyle
  ) {
    final isEnabled = timeRecord.elapsedTime != '' && 
                     timeRecord.elapsedTime != 'TBD';

    return SizedBox(
      width: 100,
      child: TextField(
        controller: null,
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

  void _handleTimeSubmission(String newValue, int index, TimingRecord timeRecord) {
    if (newValue.isNotEmpty && _timeIsValid(newValue, index, _timingData.records)) {
      timeRecord.elapsedTime = newValue;
    } else {
      // Reset to previous value
      // _finishTimeControllers[index]?.text = timeRecord['finish_time'];
    }
  }

  Widget _buildRunnerTimeRecord(BuildContext context, int index, TimingRecord timeRecord) {
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
                  // _controllers.removeAt(getNumberOfTimes(_timingData.records) - 1);
                  _timingData.records.removeAt(index);
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
