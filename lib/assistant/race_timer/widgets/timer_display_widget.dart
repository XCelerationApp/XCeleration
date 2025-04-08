import 'package:flutter/material.dart';
import '../../../utils/time_formatter.dart';

class TimerDisplayWidget extends StatelessWidget {
  final DateTime? startTime;
  final Duration? endTime;

  const TimerDisplayWidget({
    super.key,
    required this.startTime,
    required this.endTime,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(milliseconds: 10)),
      builder: (context, _) {
        final elapsed = _calculateElapsedTime(startTime, endTime);
        return Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(vertical: 16),
          margin: const EdgeInsets.symmetric(vertical: 8),
          width: MediaQuery.of(context).size.width * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              TimeFormatter.formatDurationWithZeros(elapsed),
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width * 0.135,
                fontFamily: 'RobotoMono',
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
        );
      },
    );
  }

  Duration _calculateElapsedTime(DateTime? startTime, Duration? endTime) {
    if (startTime == null) {
      return endTime ?? Duration.zero;
    }
    return DateTime.now().difference(startTime);
  }
}
