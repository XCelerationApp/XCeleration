import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'google_drive_service.dart';

class GoogleDriveFilePicker extends StatefulWidget {
  const GoogleDriveFilePicker({super.key});

  @override
  GoogleDriveFilePickerState createState() => GoogleDriveFilePickerState();
}

class GoogleDriveFilePickerState extends State<GoogleDriveFilePicker> {
  List<drive.File> _files = [];
  bool _isLoading = true;
  String? _errorMessage;
  final GoogleDriveService _driveService = GoogleDriveService.instance;
  
  @override
  void initState() {
    super.initState();
    _loadFiles();
  }
  
  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final signedIn = await _driveService.signInAndSetup();
      if (!signedIn) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to sign in to Google. Please try again.';
        });
        return;
      }
      
      final files = await _driveService.listSpreadsheetFiles();
      setState(() {
        _files = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading files: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Google Drive File'),
        backgroundColor: const Color(0xFFE2572B),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFiles,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFE2572B),
        ),
      );
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFiles,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE2572B),
                foregroundColor: Colors.white,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }
    
    if (_files.isEmpty) {
      return const Center(
        child: Text(
          'No spreadsheet files found in your Google Drive.',
          textAlign: TextAlign.center,
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final file = _files[index];
        return ListTile(
          leading: _getFileIcon(file.mimeType),
          title: Text(file.name ?? 'Unnamed File'),
          onTap: () {
            Navigator.of(context).pop(file);
          },
        );
      },
    );
  }
  
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
}
