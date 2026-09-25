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
        // Scales down rather than wrapping on a narrow phone or at a large
        // text size; even-width digits keep it from jittering as it counts.
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            TimeFormatter.formatDurationWithZeros(elapsed),
            maxLines: 1,
            style: AppTypography.displayLarge.copyWith(
              letterSpacing: -0.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
      },
    );
  }
}
