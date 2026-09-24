import 'package:flutter/material.dart';
import '../../../core/utils/time_formatter.dart';
import '../../../core/theme/typography.dart';
import '../controller/timing_controller.dart';

class TimerDisplayWidget extends StatelessWidget {
  final TimingController controller;
  const TimerDisplayWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: (controller.raceStopped || controller.startTime == null)
          ? const Stream<int>.empty()
          : Stream.periodic(const Duration(milliseconds: 10)),
      builder: (context, _) {
        final elapsed = controller.raceElapsed;
        return Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(vertical: 8),
          width: MediaQuery.of(context).size.width * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            TimeFormatter.formatDurationWithZeros(elapsed),
            style: AppTypography.displayLarge.copyWith(
              fontSize: MediaQuery.of(context).size.width * 0.11,
              letterSpacing: -0.5,
            ),
          ),
        );
      },
    );
  }

}
