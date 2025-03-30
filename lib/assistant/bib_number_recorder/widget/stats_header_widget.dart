import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart';
import 'package:xcelerate/core/theme/app_colors.dart';
import '../model/bib_records_provider.dart';
import '../model/bib_number_model.dart';

class StatsHeaderWidget extends StatefulWidget {
  final List<RunnerRecord> runners;
  final BibNumberModel model;
  final Function() onReset;

  const StatsHeaderWidget({
    super.key,
    required this.runners,
    required this.model,
    required this.onReset,
  });

  @override
  State<StatsHeaderWidget> createState() => _StatsHeaderWidgetState();
}

class _StatsHeaderWidgetState extends State<StatsHeaderWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _countAnimationController;
  late Animation<double> _scaleAnimation;
  int _previousCount = 0;

  @override
  void initState() {
    super.initState();
    _countAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _countAnimationController,
        curve: Curves.easeOutBack,
      ),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _countAnimationController.reverse();
        }
      });
  }

  @override
  void dispose() {
    _countAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BibRecordsProvider>(
      builder: (context, provider, _) {
        final currentCount = widget.model.countNonEmptyBibNumbers(context);

        // Trigger animation when count changes
        if (_previousCount != currentCount) {
          _countAnimationController.forward(from: 0.0);
          _previousCount = currentCount;
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(0.0, 16.0, 0.0, 8.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // // Title
                    // Text(
                    //   'Bib Numbers',
                    //   style: TextStyle(
                    //     color: Colors.grey[600],
                    //     fontSize: 16,
                    //     fontWeight: FontWeight.w500,
                    //     letterSpacing: 0.5,
                    //   ),
                    // ),

                    // const SizedBox(height: 12),

                    // Animated bib count - the primary focus
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$currentCount',
                            style: const TextStyle(
                              color: Color(0xFF2D3142),
                              fontSize: 54,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Bibs Recorded',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Bottom row with secondary information and actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Runners count
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 18,
                                color: Colors.grey[700],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Runners: ${widget.runners.length}',
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Reset button - less prominent but accessible
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onReset,
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryColor,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.refresh,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Reset',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
