import 'dart:io';
import 'package:flutter/material.dart';

import 'google_drive_service.dart';
import 'file_utils.dart';

/// Result model for spreadsheet picking operations
class SpreadsheetPickResult {
  final List<List<dynamic>> data;
  final String? fileName;
  final String source; // 'local', 'drive-csv', 'drive-xlsx', 'drive-sheets'
  
  SpreadsheetPickResult({
    required this.data, 
    this.fileName, 
    required this.source
  });
}

/// Service for picking and processing spreadsheet files
/// from either local storage or Google Drive
/// 
/// This service has been refactored to use the new architecture with drive.file scope
/// It maintains backward compatibility with existing code
class SpreadsheetFilePickerService {
  static final GoogleDriveService _driveService = GoogleDriveService.instance;
  
  /// Pick a spreadsheet file from either local storage or Google Drive
  /// Uses the new services architecture with drive.file scope for Google Drive
  static Future<SpreadsheetPickResult?> pickSpreadsheetFile(BuildContext context, {bool driveOnly = false}) async {
    // If driveOnly is true, skip the dialog and go directly to Drive
    final choice = driveOnly ? 'drive' : await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Source'),
        content: const Text('Pick a spreadsheet from local storage or Google Drive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'local'), child: const Text('Local')), 
          TextButton(onPressed: () => Navigator.pop(ctx, 'drive'), child: const Text('Google Drive')),
        ],
      ),
    );
    
    if (choice == null) return null; // User canceled
    
    File? selectedFile;
    String source = '';
    
    if (choice == 'local') {
      // Use FileUtils for local file picking
      selectedFile = await FileUtils.pickLocalSpreadsheetFile();
      source = 'local';
    } else {
      // Use GoogleDriveService with drive.file scope for Drive picking
      selectedFile = await _driveService.pickSpreadsheetFile(context);
      source = 'drive';
    }
    
    if (selectedFile == null) return null;
    
    // Process the selected file
    final fileName = selectedFile.path.split('/').last;
    
    // Parse the spreadsheet data using FileUtils
    final data = await FileUtils.parseSpreadsheetFile(selectedFile);
    if (data == null || data.isEmpty) return null;
    
    return SpreadsheetPickResult(
      data: data,
      fileName: fileName,
      source: source,
    );
  }
}

// Removed legacy Dialog implementation as it has been replaced by Google Picker API
