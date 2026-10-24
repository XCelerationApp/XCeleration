import 'package:flutter/material.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';
import '../controller/load_results_controller.dart';

/// For a coach who recorded the bibs on this phone: takes them as the Bib
/// Recorder's results, since a phone cannot send to itself. Shown only when
/// this phone's Bib Recorder has bibs for the race.
class UseBibsFromThisPhone extends StatefulWidget {
  const UseBibsFromThisPhone({super.key, required this.controller});

  final LoadResultsController controller;

  @override
  State<UseBibsFromThisPhone> createState() => _UseBibsFromThisPhoneState();
}

class _UseBibsFromThisPhoneState extends State<UseBibsFromThisPhone> {
  String? _bibs;

  @override
  void initState() {
    super.initState();
    widget.controller.bibsFromThisPhone().then((bibs) {
      if (mounted) setState(() => _bibs = bibs);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bibs = _bibs;
    if (bibs == null) return const SizedBox.shrink();
    final bibRecorder = widget.controller.devices.bibRecorder;
    if (bibRecorder == null || bibRecorder.isFinished) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: TextButton.icon(
        key: const ValueKey('use_bibs_from_this_phone'),
        onPressed: () => widget.controller.useBibsFromThisPhone(context, bibs),
        icon: const Icon(Icons.smartphone, size: 18),
        label: const Text('Use Bibs From This Phone'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryColor,
          textStyle: AppTypography.smallBodySemibold,
        ),
      ),
    );
  }
}
