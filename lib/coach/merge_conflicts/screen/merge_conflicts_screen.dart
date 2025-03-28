import 'package:flutter/material.dart';
import 'package:xcelerate/coach/merge_conflicts/controller/merge_conflicts_controller.dart';
import 'package:xcelerate/coach/merge_conflicts/model/chunk.dart';
import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/app_colors.dart';
import '../../../utils/enums.dart';
import '../model/timing_data.dart';
import '../model/joined_record.dart';
import '../../../assistant/race_timer/timing_screen/model/timing_record.dart';
import '../../../core/components/instruction_card.dart';

class MergeConflictsScreen extends StatefulWidget {
  final int raceId;
  final TimingData timingData;
  final List<RunnerRecord> runnerRecords;

  const MergeConflictsScreen({
    super.key, 
    required this.raceId,
    required this.timingData,
    required this.runnerRecords,
  });

  @override
  State<MergeConflictsScreen> createState() => _MergeConflictsScreenState();
}

class _MergeConflictsScreenState extends State<MergeConflictsScreen> {
  late MergeConflictsController _controller;

  @override
  void initState() {
    super.initState();
    _initializeState();
    
    // Add listener to rebuild UI when controller data changes
    _controller.addListener(_rebuildUi);
  }
  
  void _rebuildUi() {
    if (mounted) {
      setState(() {});
    }
  }

  void _initializeState() {
    _controller = MergeConflictsController(
      raceId: widget.raceId,
      timingData: widget.timingData,
      runnerRecords: widget.runnerRecords,
    );
    _controller.setContext(context);
    _controller.initState();
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    _controller.updateRunnerInfo();
  }

  Widget _buildConfirmationRecord(BuildContext context, int index, TimingRecord timeRecord) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Confirmed',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              timeRecord.elapsedTime,
              style: TextStyle(
                color: AppColors.darkColor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Set the controller's context
    _controller.setContext(context);
    
    // final timeRecords = _timingData.records;

    return Scaffold(
      body: Container(
        color: AppColors.backgroundColor,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_controller.getFirstConflict()[0] == null)
                _buildSaveButton(_controller),
              Expanded(
                child: _buildInstructionsAndList(_controller),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton(MergeConflictsController controller) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: ElevatedButton(
        onPressed: () => controller.saveResults(),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Finished Merging Conflicts',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsAndList(MergeConflictsController controller) {
    if (controller.timingData.records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No race results to review',
              style: AppTypography.titleSemibold.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildResultsList(controller),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // const SizedBox(height: 16),
        // Container(
        //   padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        //   child: Text(
        //     'Merge Conflicts',
        //     style: AppTypography.displayLarge.copyWith(
        //       color: AppColors.darkColor,
        //       fontSize: 28,
        //     ),
        //   ),
        // ),
        _buildInstructionsCard(),
      ],
    );
  }

  Widget _buildInstructionsCard() {
    return InstructionCard(
      title: 'Review Race Results',
      instructions: [
        InstructionItem(number: '1', text: 'Find the runners with the unknown times (orange)'),
        InstructionItem(number: '2', text: 'Update times as needed'),
        InstructionItem(number: '3', text: 'Save when all results are confirmed'),
      ],
    );
  }

  Widget _buildResultsList(MergeConflictsController controller) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: controller.chunks.length,
      itemBuilder: (context, index) => _buildChunkItem(context, index, controller.chunks[index], controller),
    );
  }

  Widget _buildRunnerTimeRecord(BuildContext context, int index, JoinedRecord joinedRecord, Color color, Chunk chunk, MergeConflictsController controller) {
    final RunnerRecord runner = joinedRecord.runner;
    final TimingRecord timeRecord = joinedRecord.timeRecord;
    final hasConflict = chunk.resolve != null;
    
    final Color conflictColor = hasConflict ? AppColors.primaryColor : Colors.green;
    final Color bgColor = conflictColor.withOpacity(0.05);
    final Color borderColor = conflictColor.withOpacity(0.5);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0.3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: borderColor, width: 0.5),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildPlaceNumber(timeRecord.place!, conflictColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildRunnerInfo(runner, conflictColor),
                    ),
                  ],
                ),
              ),
            ),
            Container(width: 0.5, color: borderColor),
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: hasConflict
                  ? _buildTimeSelector(
                      controller,
                      chunk.controllers['timeControllers']![index],
                      chunk.controllers['manualControllers']![index],
                      chunk.resolve!.availableTimes,
                      chunk.conflictIndex,
                      manual: chunk.type != RecordType.extraRunner,
                    )
                  : _buildConfirmedTime(timeRecord.elapsedTime),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceNumber(int place, Color color) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 0.5,
        ),
      ),
      child: Center(
        child: Text(
          '#$place',
          style: TextStyle(
            color: color.withOpacity(0.9),
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildRunnerInfo(RunnerRecord runner, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          runner.name,
          style: AppTypography.bodySemibold.copyWith(
            color: AppColors.darkColor,
            fontSize: 14,
            letterSpacing: -0.1,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            if (runner.bib.isNotEmpty)
              _buildInfoChip('Bib ${runner.bib}', accentColor),
            if (runner.school.isNotEmpty)
              _buildInfoChip(runner.school, AppColors.mediumColor.withOpacity(0.8)),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 11,
          letterSpacing: -0.1,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildConfirmedTime(String time) {
    return Container(
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            time,
            style: TextStyle(
              color: AppColors.darkColor,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelector(
    MergeConflictsController controller,
    TextEditingController timeController,
    TextEditingController? manualController,
    List<String> times,
    int conflictIndex,
    {bool manual = true}
  ) {
    final availableOptions = times.where((time) => 
      time == timeController.text || !controller.selectedTimes[conflictIndex].contains(time)
    ).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: availableOptions.contains(timeController.text) ? timeController.text : null,
          hint: Text(
            timeController.text.isEmpty ? 'Select Time' : timeController.text,
            style: TextStyle(
              color: AppColors.darkColor,
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
          items: [
            if (manual) 
              DropdownMenuItem<String>(
                value: 'manual_entry',
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.25,
                  child: TextField(
                    controller: manualController,
                    style: TextStyle(
                      color: AppColors.darkColor,
                      fontWeight: FontWeight.w500,
                    ),
                    cursorColor: AppColors.primaryColor,
                    decoration: InputDecoration(
                      hintText: 'Enter time',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        setState(() {
                          timeController.text = value;
                          if (controller.selectedTimes[conflictIndex].contains(timeController.text)) {
                            controller.selectedTimes[conflictIndex].remove(timeController.text);
                          }
                        });
                      }
                    },
                  ),
                ),
              ),
            ...availableOptions.map((time) => DropdownMenuItem<String>(
              value: time,
              child: Text(
                time,
                style: TextStyle(
                  color: AppColors.darkColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            )),
          ],
          onChanged: (value) {
            if (value == null) return;
            if (value == 'manual_entry') return;
            
            final previousValue = timeController.text;
            setState(() {
              timeController.text = value;
              controller.selectedTimes[conflictIndex].add(value);
              if (previousValue != value && previousValue.isNotEmpty) {
                controller.selectedTimes[conflictIndex].remove(previousValue);
              }
              if (manualController != null) {
                manualController.clear();
              }
            });
          },
          dropdownColor: Colors.white,
          icon: Icon(
            Icons.arrow_drop_down,
            color: AppColors.primaryColor,
            size: 28,
          ),
          isExpanded: true,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildChunkItem(BuildContext context, int index, Chunk chunk, MergeConflictsController controller) {
    final chunkType = chunk.type;
    final record = chunk.records.last;
    final previousChunk = index > 0 ? controller.chunks[index - 1] : null;
    final previousChunkEndTime = previousChunk != null ? previousChunk.records.last.elapsedTime : '0.0';
    

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (chunkType == RecordType.extraRunner || chunkType == RecordType.missingRunner)
            _buildConflictHeader(chunkType, record, previousChunkEndTime, record.elapsedTime),
          if (chunkType == RecordType.confirmRunner)
            _buildConfirmHeader(record),
          const SizedBox(height: 8),
          ...chunk.joinedRecords.map<Widget>((joinedRecord) {
            if (joinedRecord.timeRecord.type == RecordType.runnerTime) {
              return _buildRunnerTimeRecord(
                context,
                chunk.joinedRecords.indexOf(joinedRecord),
                joinedRecord,
                chunkType == RecordType.runnerTime || chunkType == RecordType.confirmRunner
                    ? Colors.green
                    : AppColors.primaryColor,
                chunk,
                controller,
              );
            } else if (joinedRecord.timeRecord.type == RecordType.confirmRunner) {
              return _buildConfirmationRecord(
                context,
                chunk.joinedRecords.indexOf(joinedRecord),
                joinedRecord.timeRecord,
              );
            }
            return const SizedBox.shrink();
          }),
          if (chunkType == RecordType.extraRunner || chunkType == RecordType.missingRunner)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: _buildActionButton(
                'Resolve Conflict',
                () => chunk.handleResolve(
                  controller.handleTooManyTimesResolution,
                  controller.handleTooFewTimesResolution,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConflictHeader(RecordType type, TimingRecord conflictRecord, String startTime, String endTime) {
    final String title = type == RecordType.extraRunner
        ? 'Too Many Runner Times'
        : 'Missing Runner Times';
    final String description = '${type == RecordType.extraRunner
        ? 'There are more times recorded by the timing assistant than runners'
        : 'There are more runners than times recorded by the timing assistant'}. Please select or enter appropriate times between $startTime and $endTime to resolve the discrepancy between recorded times and runners.';
    final IconData icon = type == RecordType.extraRunner
        ? Icons.group_add
        : Icons.person_search;
        
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title at ${conflictRecord.elapsedTime}',
                  style: TextStyle(
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: AppColors.primaryColor.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmHeader(TimingRecord confirmRecord) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirmed Results at ${confirmRecord.elapsedTime}',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'These runner results have been confirmed',
                  style: TextStyle(
                    color: Colors.green.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sync_problem, size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
  @override
  void dispose() {
    // Remove the listener when the widget is disposed
    _controller.removeListener(_rebuildUi);
    super.dispose();
  }
}
