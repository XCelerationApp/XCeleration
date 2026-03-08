import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SampleSpreadsheetSheet extends StatelessWidget {
  const SampleSpreadsheetSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: rootBundle
          .loadString('assets/sample_sheets/sample_spreadsheet.csv'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final lines = snapshot.data!.split('\n');
        final table = Table(
          border: TableBorder.all(color: Colors.grey),
          children: lines.map((line) {
            final cells = line.split(',');
            return TableRow(
              children: cells.map((cell) {
                return TableCell(
                  verticalAlignment: TableCellVerticalAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(cell),
                  ),
                );
              }).toList(),
            );
          }).toList(),
        );
        return SingleChildScrollView(child: table);
      },
    );
  }
}
