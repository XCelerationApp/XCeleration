import 'dart:io';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'google_drive_service.dart';

class GoogleDrivePicker {
  static final GoogleDrivePicker _instance = GoogleDrivePicker._internal();
  final GoogleDriveService _driveService = GoogleDriveService.instance;
  
  factory GoogleDrivePicker() {
    return _instance;
  }
  
  GoogleDrivePicker._internal();
  
  /// Opens a native-looking Google Drive file picker and returns the selected file
  Future<File?> pickFile(BuildContext context, {List<String> allowedExtensions = const ['csv', 'xlsx']}) async {
    try {
      // Sign in to Google
      final signInSuccess = await _driveService.signInAndSetup();
      if (!signInSuccess) {
        _showMessage(context, 'Failed to sign in to Google Drive');
        return null;
      }
      
      // Show a loading dialog
      _showLoadingDialog(context);
      
      // Get files from Google Drive
      final driveFiles = await _driveService.listSpreadsheetFiles();
      
      // Dismiss loading dialog
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      if (driveFiles.isEmpty) {
        _showMessage(context, 'No spreadsheet files found in your Google Drive');
        return null;
      }
      
      // Show a more native-looking file picker dialog with a proper StatefulWidget
      final selectedFile = await showDialog<drive.File>(
        context: context,
        builder: (context) => _DriveFilePickerDialog(driveFiles: driveFiles, fileIconBuilder: _getFileIcon),
      );
      
      if (selectedFile == null) {
        return null;
      }
      
      // Show download dialog
      _showLoadingDialog(context, message: 'Loading ${selectedFile.name}...');
      
      // Download the file
      final tempFile = await _driveService.downloadFile(
        selectedFile.id!,
        selectedFile.name ?? 'spreadsheet'
      );
      
      // Dismiss download dialog
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      return tempFile;
    } catch (e) {
      // Make sure to dismiss dialog if there was an error
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      _showMessage(context, 'Error picking file: $e');
      return null;
    }
  }

  // Get the appropriate icon based on file mime type
  Widget _getFileIcon(String? mimeType) {
    IconData iconData;
    Color iconColor;
    
    if (mimeType == 'application/vnd.google-apps.spreadsheet') {
      iconData = Icons.table_chart;
      iconColor = Colors.green;
    } else if (mimeType?.contains('spreadsheet') == true || 
              mimeType?.contains('excel') == true) {
      iconData = Icons.table_chart;
      iconColor = Colors.green;
    } else if (mimeType?.contains('csv') == true) {
      iconData = Icons.insert_drive_file;
      iconColor = Colors.blue;
    } else {
      iconData = Icons.insert_drive_file;
      iconColor = Colors.grey;
    }
    
    return Icon(
      iconData,
      color: iconColor,
    );
  }
  
  AlertDialog _showLoadingDialog(BuildContext context, {String message = 'Loading files from Google Drive...'}) {
    AlertDialog alert = AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE2572B)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
    
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
    
    return alert;
  }
  
  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

/// A StatefulWidget for the Google Drive file picker dialog
class _DriveFilePickerDialog extends StatefulWidget {
  final List<drive.File> driveFiles;
  final Widget Function(String?) fileIconBuilder;

  const _DriveFilePickerDialog({
    super.key,
    required this.driveFiles,
    required this.fileIconBuilder,
  });

  @override
  _DriveFilePickerDialogState createState() => _DriveFilePickerDialogState();
}

class _DriveFilePickerDialogState extends State<_DriveFilePickerDialog> {
  late List<drive.File> filteredFiles;
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    filteredFiles = List<drive.File>.from(widget.driveFiles);
    
    // Add listener to properly update UI when text changes
    _searchController.addListener(_filterFiles);
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_filterFiles);
    _searchController.dispose();
    super.dispose();
  }
  
  // Helper method to show a hint message about file selection
  void _showFileSelectionHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please tap on a file to select it'),
        backgroundColor: Color(0xFFE2572B),
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  // Helper method to get a subtitle for file items
  Widget _getFileTypeLabel(String? mimeType) {
    if (mimeType == 'application/vnd.google-apps.spreadsheet') {
      return const Text('Google Sheets', style: TextStyle(fontSize: 12, color: Colors.grey));
    } else if (mimeType?.contains('excel') == true || mimeType?.contains('spreadsheet') == true) {
      return const Text('Excel file', style: TextStyle(fontSize: 12, color: Colors.grey));
    } else if (mimeType?.contains('csv') == true) {
      return const Text('CSV file', style: TextStyle(fontSize: 12, color: Colors.grey));
    } else {
      return const Text('Document', style: TextStyle(fontSize: 12, color: Colors.grey));
    }
  }
  
  void _filterFiles() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredFiles = List<drive.File>.from(widget.driveFiles);
      } else {
        filteredFiles = widget.driveFiles.where((file) {
          final name = file.name?.toLowerCase() ?? '';
          return name.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        dialogTheme: DialogThemeData(backgroundColor: Colors.white),
      ),
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud, color: Color(0xFFE2572B), size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Import from Google Drive',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              // Search bar
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search files...',
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey.shade600),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: const Color(0xFFE2572B), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                ),
              ),
              // File list
              Expanded(
                child: filteredFiles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.search_off, size: 48, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No files found',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredFiles.length,
                        itemBuilder: (context, index) {
                          final file = filteredFiles[index];
                          return ListTile(
                            leading: widget.fileIconBuilder(file.mimeType),
                            title: Text(
                              file.name ?? 'Unnamed File',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15),
                            ),
                            subtitle: _getFileTypeLabel(file.mimeType),
                            dense: true,
                            onTap: () => Navigator.of(context).pop(file),
                          );
                        },
                      ),
              ),
              // Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: filteredFiles.isNotEmpty 
                          ? () => _showFileSelectionHint() 
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE2572B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: const Text('Select a File', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
