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
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _countAnimationController,
        curve: Curves.elasticOut,
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

        // Determine color based on count
        Color countColor = Colors.black;
        if (currentCount > 0) {
          countColor = AppColors.primaryColor;
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(0.0, 16.0, 0.0, 16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 5),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
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
                            style: TextStyle(
                              color: countColor,
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
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 20,
                                color: Colors.grey[800],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Runners: ${widget.runners.length}',
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Reset button - less prominent but accessible
                        Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                          child: InkWell(
                            onTap: currentCount > 0 ? widget.onReset : null,
                            borderRadius: BorderRadius.circular(24),
                            child: Opacity(
                              opacity: currentCount > 0 ? 1.0 : 0.5,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.refresh,
                                      size: 18,
                                      color: AppColors.primaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Reset',
                                      style: TextStyle(
                                        color: AppColors.primaryColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
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
