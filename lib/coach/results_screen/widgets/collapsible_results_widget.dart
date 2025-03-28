import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';
import '../model/results_record.dart';

class CollapsibleResultsWidget extends StatefulWidget {
  final List<ResultsRecord> allResults;
  final int initialVisibleCount;
  final bool isExpanded;
  final VoidCallback onToggleExpansion;

  const CollapsibleResultsWidget({
    super.key,
    required this.allResults,
    this.initialVisibleCount = 3,
    required this.isExpanded,
    required this.onToggleExpansion,
  });

  @override
  State<CollapsibleResultsWidget> createState() => _CollapsibleResultsWidgetState();
}

class _CollapsibleResultsWidgetState extends State<CollapsibleResultsWidget> {
  @override
  Widget build(BuildContext context) {
    final displayResults = widget.isExpanded 
        ? widget.allResults 
        : widget.allResults.take(widget.initialVisibleCount).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Individual Results',
                  style: AppTypography.titleSemibold,
                ),
                Text(
                  '${widget.allResults.length} Runners',
                  style: AppTypography.bodyRegular.copyWith(
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  SizedBox(width: 40, child: Text('Rank', style: AppTypography.bodySemibold)),
                  Expanded(flex: 1, child: Text('Name', style: AppTypography.bodySemibold)),
                  Expanded(flex: 1, child: Text('School', style: AppTypography.bodySemibold)),
                  Expanded(flex: 1, child: Text('Time', style: AppTypography.bodySemibold)),
                ],
              ),
            ),
            const Divider(),
            ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: displayResults.length,
              itemBuilder: (context, index) {
                final runner = displayResults[index];
                // Use subtle alternate row colors for better readability
                final backgroundColor = index % 2 == 0 
                    ? Colors.transparent 
                    : Colors.grey.withOpacity(0.05);
                
                return Container(
                  color: backgroundColor,
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${runner.place}', 
                          style: AppTypography.bodyRegular,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          runner.name,
                          style: AppTypography.bodyRegular,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          runner.school,
                          style: AppTypography.bodyRegular,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          runner.formattedFinishTime,
                          style: AppTypography.bodyRegular,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (widget.allResults.length > widget.initialVisibleCount) ...[
              const SizedBox(height: 16),
              Container(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.onToggleExpansion,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                  ),
                  child: Text(
                    widget.isExpanded ? 'See Less' : 'See More',
                    style: AppTypography.smallBodyRegular,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
