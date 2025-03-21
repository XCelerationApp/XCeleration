import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/bib_records_provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/components/button_utils.dart';

class BottomActionButtonsWidget extends StatelessWidget {
  final VoidCallback onShareBibNumbers;

  const BottomActionButtonsWidget({
    super.key,
    required this.onShareBibNumbers,
  });

  @override
  Widget build(BuildContext context) {
    final bibRecordsProvider = Provider.of<BibRecordsProvider>(context, listen: false);
    final hasNonEmptyBibNumbers = bibRecordsProvider.bibRecords.any((record) => record.bib.isNotEmpty);

    if (!hasNonEmptyBibNumbers) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: RoundedRectangleButton(
        text: 'Share Bib Numbers',
        color: AppColors.navBarColor,
        width: double.infinity,
        height: 50,
        fontSize: 18,
        onPressed: onShareBibNumbers,
      ),
    );
  }
}
