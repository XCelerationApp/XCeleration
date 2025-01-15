import 'package:flutter/material.dart';
import '../constants.dart';
import '../utils/time_formatter.dart';

class ConflictResolutionDialog extends StatelessWidget {
  final List<dynamic> conflictingRunners;
  final dynamic lastConfirmedRecord;
  final dynamic nextConfirmedRecord;
  final List<String> availableTimes;
  final bool allowManualEntry;
  final Map<String, dynamic> conflictRecord;
  final Function(List<Duration>) onResolve;

  const ConflictResolutionDialog({super.key, 
    required this.conflictingRunners,
    required this.lastConfirmedRecord,
    required this.nextConfirmedRecord,
    required this.availableTimes,
    this.allowManualEntry = false,
    required this.conflictRecord,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final timeControllers = List.generate(
      conflictingRunners.length, 
      (_) => TextEditingController()
    );
    final manualEntryControllers = allowManualEntry ? 
      List.generate(conflictingRunners.length, (_) => TextEditingController()) : 
      null;

    return AlertDialog(
      title: Text(allowManualEntry ? 'Enter Time' : 'Select Time'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lastConfirmedRecord.isNotEmpty) 
              _buildRunnerRow(lastConfirmedRecord, isConfirmed: true),
            ...List.generate(
              conflictingRunners.length,
              (index) => _buildTimeSelectionRow(
                conflictingRunners[index],
                timeControllers[index],
                manualEntryControllers?[index],
                availableTimes,
              ),
            ),
            if (nextConfirmedRecord.isNotEmpty) 
              _buildRunnerRow(nextConfirmedRecord, isConfirmed: true),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () => _handleResolve(
            context, 
            timeControllers, 
            conflictingRunners,
            lastConfirmedRecord,
            conflictRecord
          ),
          child: Text('Resolve'),
        ),
      ],
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
    final items = [
      ...times.map((time) => DropdownMenuItem<String>(
        value: time,
        child: Text(time),
      )),
      if (manualController != null)
        DropdownMenuItem<String>(
          value: 'manual',
          child: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: MediaQuery.of(context).size.width * 0.25,
                child: TextField(
                  controller: manualController,
                  decoration: InputDecoration(
                    hintText: 'Enter time',
                    border: InputBorder.none,
                  ),
                )
              );
            }
          ),
        ),
    ];

    return DropdownButtonFormField<String>(
      value: timeController.text.isNotEmpty ? timeController.text : null,
      items: items,
      onChanged: (value) => _handleTimeSelection(
        timeController,
        manualController,
        value,
      ),
      decoration: InputDecoration(hintText: 'Select Time'),
    );
  }

  void _handleTimeSelection(
    TextEditingController timeController,
    TextEditingController? manualController,
    String? value,
  ) {
    if (value == 'manual' && manualController != null) {
      timeController.text = manualController.text;
    }
    else {
      timeController.text = value ?? '';
      if (manualController?.text.isNotEmpty == true && (value == null || value == '')) {
        timeController.text = manualController!.text;
      }
    }

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
      onResolve(times);
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
    final lastConfirmedTime = lastConfirmed.isEmpty ? Duration.zero : loadDurationFromString(lastConfirmed['finish_time']);

    for (var i = 0; i < controllers.length; i++) {
      final time = _parseTime(controllers[i].text);
      if (time == null) {
        _showError(context, 'Invalid time format for ${runners[i]['name']}');
        return null;
      }
      
      if (time <= lastConfirmedTime) {
        _showError(context, 'Time must be after ${lastConfirmed['finish_time']}');
        return null;
      }

      if (time >= loadDurationFromString(conflictRecord['finish_time'])) {
        _showError(context, 'Time must be before ${conflictRecord['finish_time']}');
        return null;
      }
      
      formattedTimes.add(time);
    }

    if (!_isAscendingOrder(formattedTimes)) {
      _showError(context, 'Times must be in ascending order');
      return null;
    }

    return formattedTimes;
  }
}

// Helper functions
Duration? _parseTime(String input) {
  if (input.isEmpty || input == '') return null;
  
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

void _showError(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Error'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('OK'),
        ),
      ],
    ),
  );
}