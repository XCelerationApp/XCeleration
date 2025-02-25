import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/time_formatter.dart';
import '../utils/dialog_utils.dart';

class ConflictResolutionScreen extends StatefulWidget {
  final List<dynamic> conflictingRunners;
  final List<String> availableTimes;
  final dynamic lastConfirmedRecord;
  final dynamic nextConfirmedRecord;
  final bool allowManualEntry;
  final Map<String, dynamic> conflictRecord;
  final Function(List<Duration>) onResolve;

  final List<String> selectedTimes;
  
  late final List<TextEditingController> timeControllers;
  late final List<TextEditingController>? manualEntryControllers;

  ConflictResolutionScreen({
    super.key,
    required this.conflictRecord,
    required this.onResolve,
    required this.selectedTimes,
    required this.conflictingRunners,
    required this.lastConfirmedRecord,
    required this.nextConfirmedRecord,
    required this.availableTimes,
    this.allowManualEntry = false,
  }) {
    timeControllers = List.generate(
        conflictingRunners.length, 
        (_) => TextEditingController()
    );
    manualEntryControllers = allowManualEntry ? 
        List.generate(conflictingRunners.length, (_) => TextEditingController()) : 
        null;
  }

  @override
  ConflictResolutionScreenState createState() => ConflictResolutionScreenState();
}

class ConflictResolutionScreenState extends State<ConflictResolutionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.allowManualEntry ? 'Enter Time' : 'Select Time'),
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () => _handleResolve(
              context, 
              widget.timeControllers, 
              widget.conflictingRunners,
              widget.lastConfirmedRecord,
              widget.conflictRecord
            ),
            child: Text('Resolve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.lastConfirmedRecord.isNotEmpty) ...[
                _buildRunnerRow(widget.lastConfirmedRecord, isConfirmed: true),
                Divider(),
              ],
              Expanded(
                child: ListView.separated(
                  itemCount: widget.conflictingRunners.length,
                  separatorBuilder: (context, index) => Divider(),
                  itemBuilder: (context, index) => _buildTimeSelectionRow(
                    widget.conflictingRunners[index],
                    widget.timeControllers[index],
                    widget.manualEntryControllers?[index],
                    widget.availableTimes,
                  ),
                ),
              ),
              if (widget.nextConfirmedRecord.isNotEmpty) ...[
                Divider(),
                _buildRunnerRow(widget.nextConfirmedRecord, isConfirmed: true),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRunnerRow(Map<String, dynamic> record, {bool isConfirmed = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${record['name']} #${record['bib_number']} ${record['school']}${record['finish_time'] != null ? ' - ${record['finish_time']}' : ''}',
            style: TextStyle(
              fontWeight: FontWeight.w400,
              color: isConfirmed ? AppColors.navBarTextColor : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSelectionRow(
    Map<String, dynamic> runner,
    TextEditingController timeController,
    TextEditingController? manualController,
    List<String> times,
  ) {
    return Row(
      children: [
        Expanded(child: _buildRunnerRow(runner)),
        Expanded(
          child: _buildTimeSelector(
            timeController,
            manualController,
            times,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSelector(
    TextEditingController timeController,
    TextEditingController? manualController,
    List<String> times,
  ) {
      final availableOptions = times.where((time) => time == timeController.text || !widget.selectedTimes.contains(time)).toList();
      final items = [
        ...availableOptions.map((time) => DropdownMenuItem<String>(
          value: time,
          child: Text(time),
        )),
        if (manualController != null)
          DropdownMenuItem<String>(
            value: manualController.text.isNotEmpty ? manualController.text : 'manual',
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.25,
              child: TextField(
                controller: manualController,
                decoration: InputDecoration(
                  hintText: 'Enter time',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ];

        return DropdownButtonFormField<String>(
          value: timeController.text.isNotEmpty ? timeController.text : null,
          items: items,
          onChanged: (value) {
            final previousValue = timeController.text;
            _handleTimeSelection(
              timeController,
              manualController,
              value,
            );
            if (value != null && value != 'manual') {
              setState(() {
                widget.selectedTimes.add(value);
                if (previousValue != value && previousValue.isNotEmpty) {
                  widget.selectedTimes.remove(previousValue);
                }
              });
              debugPrint('Selected times: ${widget.selectedTimes}');
            }
          },
          decoration: InputDecoration(hintText: 'Select Time'),
        );
  }

  void _handleTimeSelection(
    TextEditingController timeController,
    TextEditingController? manualController,
    String? value,
  ) {
    setState(() {
      if (value == 'manual' && manualController != null) {
        timeController.text = manualController.text;
      }
      else {
        timeController.text = value ?? '';
        if (manualController?.text.isNotEmpty == true && (value == null || value == '')) {
          timeController.text = manualController!.text;
        }
      }
    });

  }

  void _handleResolve(
    BuildContext context,
    List<TextEditingController> controllers,
    List<dynamic> runners,
    dynamic lastConfirmed,
    Map<String, dynamic> conflictRecord
  ) {
    final times = _validateAndFormatTimes(
      context,
      controllers,
      runners,
      lastConfirmed,
      conflictRecord
    );
    
    if (times != null) {
      widget.onResolve(times);
      Navigator.pop(context);
    }
  }

  List<Duration>? _validateAndFormatTimes(
    BuildContext context,
    List<TextEditingController> controllers,
    List<dynamic> runners,
    dynamic lastConfirmed,
    Map<String, dynamic> conflictRecord,
  ) {
    final List<Duration> formattedTimes = [];
    Duration? lastConfirmedTime = lastConfirmed.isEmpty ? Duration.zero : loadDurationFromString(lastConfirmed['finish_time']);
    lastConfirmedTime ??= Duration.zero;

    for (var i = 0; i < controllers.length; i++) {
      final time = _parseTime(controllers[i].text);

      if (time == null) {
        DialogUtils.showErrorDialog(context, message: 'Enter a valid time for ${runners[i]['name']}');
        return null;
      }
      
      if (time <= lastConfirmedTime) {
        DialogUtils.showErrorDialog(context, message: 'Time must be after ${lastConfirmed['finish_time']}');
        return null;
      }

      if (time >= (loadDurationFromString(conflictRecord['finish_time']) ?? Duration.zero)) {
        DialogUtils.showErrorDialog(context, message: 'Time must be before ${conflictRecord['finish_time']}');
        return null;
      }
      
      formattedTimes.add(time);
    }

    if (!_isAscendingOrder(formattedTimes)) {
      DialogUtils.showErrorDialog(context, message: 'Times must be in ascending order');
      return null;
    }

    return formattedTimes;
  }
}

// Helper functions
Duration? _parseTime(String input) {
  if (input.isEmpty || input == '' || input == 'manual') return null;
  
  final parts = input.split(':');
  final timeString = switch (parts.length) {
    1 => '00:00:$input',
    2 => '00:$input',
    3 => input,
    _ => null
  };

  if (timeString == null) return null;
  
  final millisecondParts = timeString.split('.');
  if (millisecondParts.length > 2) return null;
  
  final millisString = millisecondParts.length > 1 ? millisecondParts[1].padRight(3, '0') : '0';
  
  final timeParts = timeString.split(':');

  final hours = int.parse(timeParts[0]);
  final minutes = int.parse(timeParts[1]);
  final seconds = int.parse(timeParts[2].split('.')[0]);
  final milliseconds = int.parse(millisString);
  
  return Duration(
    hours: hours,
    minutes: minutes,
    seconds: seconds,
    milliseconds: milliseconds,
  );
}

bool _isAscendingOrder(List<Duration> times) {
  for (var i = 0; i < times.length - 1; i++) {
    if (times[i] >= times[i + 1]) return false;
  }
  return true;
}