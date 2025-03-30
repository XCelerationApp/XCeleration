import 'package:flutter/material.dart';
import 'package:xcelerate/utils/sheet_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../../race_screen/widgets/runner_record.dart';
import '../screen/resolve_bib_number_screen.dart';

class BibConflictsOverview extends StatefulWidget {
  final List<RunnerRecord> records;
  final Function(List<RunnerRecord>) onConflictSelected;
  final int raceId;

  const BibConflictsOverview({
    super.key,
    required this.records,
    required this.onConflictSelected,
    required this.raceId,
  });

  @override
  State<BibConflictsOverview> createState() => _BibConflictsOverviewState();
}

class _BibConflictsOverviewState extends State<BibConflictsOverview> {
  late List<RunnerRecord> _records;

  @override
  void initState() {
    super.initState();
    _records = widget.records;
  }

  @override
  void didUpdateWidget(BibConflictsOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.records != oldWidget.records) {
      setState(() {
        _records = widget.records;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorRecords =
        _records.where((record) => record.error != null).toList();

    if (errorRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 60,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Unfound Bib Numbers',
              style: AppTypography.titleSemibold,
            ),
            const SizedBox(height: 12),
            Text(
              'All runners have valid bib numbers',
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.mediumColor,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${errorRecords.length} Unfound Bib Numbers',
                style: AppTypography.headerSemibold.copyWith(
                  color: AppColors.darkColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a bib number to resolve',
                style: AppTypography.bodyRegular.copyWith(
                  color: AppColors.mediumColor,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
        Container(
          height: 280,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: errorRecords.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _buildConflictTile(context, errorRecords[index], index),
          ),
        ),
      ],
    );
  }

  Widget _buildConflictTile(
      BuildContext context, RunnerRecord record, int index) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.primaryColor.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () async {
          final updatedRecord = await sheet(
            context: context,
            title: 'Resolve Bib #${record.bib} Conflict',
            body: ResolveBibNumberScreen(
              record: record,
              raceId: widget.raceId,
              records: _records,
              onComplete: (record) => Navigator.pop(context, record),
            ),
          );

          if (updatedRecord != null) {
            setState(() {
              record = updatedRecord;
            });
            if (_records.every((r) => r.error == null)) {
              widget.onConflictSelected(_records);
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Hero(
                tag: 'bib-${record.bib}',
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(23),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryColor.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '#${record.bib}',
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.error ?? 'Bib number not found',
                      style: AppTypography.bodyRegular.copyWith(
                        letterSpacing: 0.1,
                      ),
                    ),
                    // const SizedBox(height: 4),
                    // Text(
                    //   record.error ?? 'Bib number not found',
                    //   style: AppTypography.bodyRegular.copyWith(
                    //     color: AppColors.mediumColor,
                    //     fontSize: 12,
                    //     height: 1.4,
                    //   ),
                    // ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
