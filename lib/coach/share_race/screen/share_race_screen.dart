// Flutter imports
import 'package:flutter/material.dart';

// Third-party package imports
import 'package:pdf/widgets.dart' as pw;

// Local imports
import '../../../core/theme/app_colors.dart';
import '../controller/share_race_controller.dart';

/// Enum defining the available formats for exporting results
enum ResultFormat {
  plainText,
  googleSheet,
  pdf,
}

class ShareSheetScreen extends StatefulWidget {
  final List<Map<String, dynamic>> teamResults;
  final List<Map<String, dynamic>> individualResults;
  final ShareRaceController controller;

  const ShareSheetScreen({
    super.key,
    required this.teamResults,
    required this.individualResults,
    required this.controller,
  });

  @override
  State<ShareSheetScreen> createState() => _ShareSheetScreenState();
}

class _ShareSheetScreenState extends State<ShareSheetScreen> {
  ResultFormat _selectedFormat = ResultFormat.plainText;

  // Text Formatting Methods
  String _getFormattedText() {
    final StringBuffer buffer = StringBuffer();
    
    // Team Results Section
    buffer.writeln('Team Results');
    buffer.writeln('Rank\tSchool\tScore\tSplit Time\tAverage Time');
    for (final team in widget.teamResults) {
      buffer.writeln(
        '${team['place']}\t${team['school']}\t${team['score']}\t'
        '${team['split']}\t${team['averageTime']}'
      );
    }
    
    // Individual Results Section
    buffer.writeln('\nIndividual Results');
    buffer.writeln('Place\tName\tSchool\tTime');
    for (final runner in widget.individualResults) {
      buffer.writeln(
        '${runner['place']}\t${runner['name']}\t${runner['school']}\t'
        '${runner['finish_time']}'
      );
    }
    
    return buffer.toString();
  }

  // Data Formatting Methods
  List<List<dynamic>> _getSheetsData() {
    final List<List<dynamic>> sheetsData = [
      // Team Results Section
      ['Team Results'],
      ['Rank', 'School', 'Score', 'Split Time', 'Average Time'],
      ...widget.teamResults.map((team) => [
        team['place'],
        team['school'],
        team['score'],
        team['split'],
        team['averageTime'],
      ]),
      
      // Spacing
      [],
      
      // Individual Results Section
      ['Individual Results'],
      ['Place', 'Name', 'School', 'Time'],
      ...widget.individualResults.map((runner) => [
        runner['place'],
        runner['name'],
        runner['school'],
        runner['finish_time'],
      ]),
    ];

    return sheetsData;
  }

  Future<pw.Document> _generatePdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          // Title
          pw.Header(
            level: 0,
            child: pw.Text('Race Results', style: pw.TextStyle(fontSize: 24)),
          ),
          
          // Team Results Section
          pw.Header(level: 1, child: pw.Text('Team Results')),
          pw.TableHelper.fromTextArray(
            headers: ['Rank', 'School', 'Score', 'Split Time', 'Average Time'],
            data: widget.teamResults.map((team) => [
              team['place'].toString(),
              team['school'].toString(),
              team['score'].toString(),
              team['split'].toString(),
              team['averageTime'].toString(),
            ]).toList(),
          ),
          
          pw.SizedBox(height: 20),
          
          // Individual Results Section
          pw.Header(level: 1, child: pw.Text('Individual Results')),
          pw.TableHelper.fromTextArray(
            headers: ['Place', 'Name', 'School', 'Time'],
            data: widget.individualResults.map((runner) => [
              runner['place'].toString(),
              runner['name'].toString(),
              runner['school'].toString(),
              runner['finish_time'].toString(),
            ]).toList(),
          ),
        ],
      ),
    );

    return pdf;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: AppColors.unselectedRoleTextColor,
              width: 1,
            ),
          ),
          child: SegmentedButton<ResultFormat>(
            selectedIcon: const Icon(
              Icons.check,
              color: AppColors.unselectedRoleColor,
            ),
            segments: const [
              ButtonSegment<ResultFormat>(
                value: ResultFormat.plainText,
                label: Center(
                  child: Text(
                    'Plain Text',
                    style: TextStyle(fontSize: 16, height: 1.2),
                  ),
                ),
              ),
              ButtonSegment<ResultFormat>(
                value: ResultFormat.googleSheet,
                label: Center(
                  child: Text(
                    'Google Sheet',
                    style: TextStyle(fontSize: 16, height: 1.2),
                  ),
                ),
              ),
              ButtonSegment<ResultFormat>(
                value: ResultFormat.pdf,
                label: Center(
                  child: Text(
                    'PDF',
                    style: TextStyle(fontSize: 16, height: 1.2),
                  ),
                ),
              ),
            ],
            selected: {_selectedFormat},
            onSelectionChanged: (Set<ResultFormat> newSelection) {
              setState(() => _selectedFormat = newSelection.first);
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) => 
                states.contains(WidgetState.selected) 
                  ? AppColors.primaryColor 
                  : AppColors.backgroundColor
              ),
              foregroundColor: WidgetStateProperty.resolveWith<Color>((states) =>
                states.contains(WidgetState.selected)
                  ? AppColors.unselectedRoleColor
                  : AppColors.unselectedRoleTextColor
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        
        // Action Buttons
        _buildActionButton(
          icon: _selectedFormat == ResultFormat.googleSheet
              ? Icons.cloud_upload
              : Icons.save,
          label: _selectedFormat == ResultFormat.googleSheet
              ? 'Export to Google Sheets'
              : 'Save Locally',
          onPressed: () => _selectedFormat == ResultFormat.googleSheet
              ? widget.controller.exportToGoogleSheets(context, _getSheetsData())
              : widget.controller.saveLocally(context, _selectedFormat, _getFormattedText(), _generatePdf),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          icon: Icons.copy,
          label: _selectedFormat == ResultFormat.googleSheet
              ? 'Copy Sheet Link'
              : 'Copy to Clipboard',
          onPressed: _selectedFormat == ResultFormat.pdf
              ? null
              : () => widget.controller.copyToClipboard(context, _selectedFormat, _getFormattedText(), _getSheetsData),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          icon: Icons.email,
          label: 'Send via Email',
          onPressed: () => widget.controller.sendEmail(context, _selectedFormat, _getFormattedText(), _getSheetsData, _generatePdf),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          icon: Icons.sms,
          label: 'Send via SMS',
          onPressed: () => widget.controller.sendSms(context, _selectedFormat, _getFormattedText(), _getSheetsData, _generatePdf),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
