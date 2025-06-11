import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:xceleration/core/utils/logger.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:xceleration/core/components/dialog_utils.dart';
import 'google_auth_service.dart';


/// A service that handles picking files from Google Drive using the Google Picker API
class GooglePickerService {
  static GooglePickerService? _instance;
  static GooglePickerService get instance => _instance ??= GooglePickerService._();
  
  final GoogleAuthService _authService = GoogleAuthService.instance;

  // Google Picker API constants
  static const String _apiKey = 'AIzaSyB-niOqpgw3cnQ5KL-OJb9_QyeQBD-WuPE';  // Your API key
  static const String _developerKey = _apiKey; 
  
  GooglePickerService._();
  
  /// Static method to pick a file from Google Drive
  /// Returns the result of the picker operation
  static Future<Map<String, dynamic>?> showPicker({required BuildContext context}) async {
    Logger.d('Opening Google Picker dialog');
    try {
      final instance = GooglePickerService.instance;
      
      return showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => GooglePickerDialog(
          onPickerResult: (result) {
            Logger.d('Picker result received: $result');
            Navigator.of(context).pop(result);
          },
          getGoogleAuthToken: () async {
            final token = await instance._authService.getAccessToken();
            Logger.d('Access token retrieved: ${token?.isNotEmpty == true ? 'Token present (${token!.length} chars)' : 'Token missing or empty'}');
            return token ?? '';
          },
          developerKey: _developerKey,
          fallbackPicker: () => FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['xlsx', 'xls', 'csv', 'ods'],
            allowMultiple: false,
          ).then((result) {
            if (result != null && result.files.isNotEmpty) {
              final file = result.files.first;
              return {
                'action': 'picked',
                'docs': [{
                  'id': 'local_${DateTime.now().millisecondsSinceEpoch}',
                  'name': file.name,
                  'url': file.path,
                  'mimeType': 'local/file',
                  'isLocalFile': true
                }]
              };
            }
            return {'action': 'canceled'};
          }),
        ),
      );
    } catch (e) {
      Logger.d('Error showing picker dialog: $e');
      return {'action': 'canceled', 'error': 'Failed to show picker: $e'};
    }
  }
  
  /// Rest of the GooglePickerService class remains the same...
  /// [Previous implementation continues here]
  
  /// Opens a file picker that allows the user to select a file from Google Drive or local storage
  /// Returns the selected file as a temporary file downloaded to the device
  /// Only allows selection of spreadsheet files (Google Sheets, CSV, XLSX)
  Future<File?> pickFile(BuildContext context) async {
    try {
      // Let user choose Drive or local
      final pickerChoice = await showDialog<String>(
        context: context,
        builder: (BuildContext dialogContext) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 320,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dialog header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: const Text(
                      'Choose File Source',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Google Drive option
                  InkWell(
                    onTap: () => Navigator.of(dialogContext).pop('google_drive'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.cloud, color: Colors.blue, size: 28),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Google Drive',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Access files from your Drive',
                                  style: TextStyle(fontSize: 13, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                  
                  const Divider(height: 32),
                  
                  // Local files option
                  InkWell(
                    onTap: () => Navigator.of(dialogContext).pop('local_files'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.folder_open, color: Colors.green, size: 28),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Local Files',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Select files from your device',
                                  style: TextStyle(fontSize: 13, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Cancel button
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(null),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          );
        },
      );
      
      // If user canceled, return null
      if (pickerChoice == null) {
        return null;
      }
      
      if (pickerChoice == 'google_drive') {
        // --- Google Drive flow ---
        final accessToken = await _authService.getAccessToken();
        if (accessToken == null) {
          Logger.d('Failed to get access token');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to authenticate with Google Drive')),
            );
          }
          return null;
        }

        // Show picker dialog with loading indicator
        Map<String, dynamic>? pickerResult;
        if (context.mounted) {
          pickerResult = await GooglePickerService.showPicker(context: context);
        }

        // Validate picker result
        if (pickerResult == null || pickerResult['action'] != 'picked') {
          Logger.d('User canceled Google Drive picker or no file selected: $pickerResult');
          return null;
        }

        final docs = pickerResult['docs'] as List?;
        if (docs == null || docs.isEmpty) {
          Logger.d('No documents selected');
          return null;
        }

        final doc = docs.first as Map<String, dynamic>;
        final fileId = doc['id'] as String?;
        final fileName = doc['name'] as String?;

        if (fileId == null || fileName == null) {
          Logger.d('Invalid document data: $doc');
          return null;
        }

        if (!_isSupportedFileType('', fileName)) {
          Logger.d('Unsupported file type: $fileName');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File format not supported. Please select a spreadsheet file (XLSX, CSV, XLS)')),
            );
          }
          return null;
        }

        try {
          // Download the file with loading dialog
          if (context.mounted) {
            final tempFile = await DialogUtils.executeWithLoadingDialog<File>(
              context,
              loadingMessage: 'Downloading file from Google Drive...',
              operation: () => _downloadFile(fileId, accessToken, fileName),
              allowCancel: true,
            );
            
            if (tempFile != null) {
              return tempFile;
            }
          }
          
          return null;
        } catch (e) {
          
          Logger.d('Error downloading file: $e');
          if (context.mounted) {
            DialogUtils.showErrorDialog(
              context,
              message: 'Download Failed: Could not download the selected file. Please try again.',
            );
          }
          return null;
        }
        
      } else if (pickerChoice == 'local_files') {
        // --- Local file flow ---
        try {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['xlsx', 'csv', 'xls'],
            allowMultiple: false,
          );
          if (result != null && result.files.single.path != null) {
            final file = File(result.files.single.path!);
            final fileName = result.files.single.name;
            if (!_isSupportedFileType('', fileName)) {
              Logger.d('Unsupported file type: $fileName');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('File format not supported. Please select a spreadsheet file (XLSX, CSV, XLS)')),
                );
              }
              return null;
            }
            return file;
          } else {
            Logger.d('User canceled local file picker or no file selected');
            return null;
          }
        } catch (e) {
          Logger.e('Error picking local file: $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error selecting file: ${e.toString()}')),
            );
          }
          return null;
        }
      }
      
      return null;
    } catch (e) {
      Logger.d('Error in picker process: $e');
      if (context.mounted) {
        DialogUtils.showErrorDialog(
          context,
          message: 'An error occurred while selecting the file. Please try again.',
        );
      }
      return null;
    }
  }
  
  /// Downloads the specified file from Google Drive
  /// Returns a temporary file on the device
  Future<File> _downloadFile(String fileId, String accessToken, String fileName) async {
    final authClient = GoogleAuthClient(accessToken);
    
    try {
      // Directly download the file binary (works with drive.file scope)
      final response = await authClient.get(
        Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId?alt=media'),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to download file: ${response.statusCode} ${response.body}');
      }
      
      // Create a temporary file
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      
      // Write the content to the file
      await file.writeAsBytes(response.bodyBytes);
      
      return file;
    } finally {
      authClient.close();
    }
  }
  
  /// Check if the file type is supported
  bool _isSupportedFileType(String mimeType, String fileName) {
    // Support Google Sheets
    if (mimeType == 'application/vnd.google-apps.spreadsheet') {
      return true;
    }
    
    // Support Excel files
    if (mimeType == 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') {
      return true;
    }
    
    // Support CSV files
    if (mimeType == 'text/csv' || fileName.toLowerCase().endsWith('.csv')) {
      return true;
    }
    
    // Support Excel files by extension
    if (fileName.toLowerCase().endsWith('.xlsx') || fileName.toLowerCase().endsWith('.xls')) {
      return true;
    }
    
    return false;
  }
}

/// A dialog widget that displays the Google Picker in a WebView
class GooglePickerDialog extends StatefulWidget {
  /// Callback function when a file is selected or the picker is closed
  final Function(Map<String, dynamic>?) onPickerResult;
  
  /// Function to get Google OAuth2 access token
  final Future<String> Function() getGoogleAuthToken;
  
  /// Google API developer key
  final String developerKey;
  
  /// Fallback local file picker function
  final Future<Map<String, dynamic>?> Function() fallbackPicker;

  const GooglePickerDialog({
    required this.onPickerResult,
    required this.getGoogleAuthToken,
    required this.developerKey,
    required this.fallbackPicker,
    super.key,
  });

  @override
  State<GooglePickerDialog> createState() => _GooglePickerDialogState();
}

class _GooglePickerDialogState extends State<GooglePickerDialog> {
  WebViewController? _webViewController;
  bool _isLoading = true;
  String? _accessToken;
  String? _errorMessage;
  Timer? _timeoutTimer;
  
  @override
  void initState() {
    super.initState();
    _initAccessToken();
    
    // Set a timeout to show fallback if picker doesn't load in 15 seconds
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _isLoading) {
        setState(() {
          _errorMessage = 'Google Drive Picker is taking too long to load. Would you like to try the local file picker instead?';
          _isLoading = false;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _webViewController = null;
    super.dispose();
  }
  
  Future<void> _initAccessToken() async {
    try {
      Logger.d('Getting access token...');
      final token = await widget.getGoogleAuthToken();
      
      Logger.d('Access token received: ${token.isNotEmpty ? 'Present (${token.length} chars)' : 'Empty or null'}');
      
      if (!mounted) return;
      
      if (token.isEmpty) {
        setState(() {
          _errorMessage = 'Could not get Google authentication token. Please check your login status.';
          _isLoading = false;
        });
        return;
      }
      
      setState(() {
        _accessToken = token;
      });
      
      // Load the WebView
      await _loadWebView();
      
    } catch (e) {
      Logger.e('Error getting access token: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to authenticate with Google: $e';
          _isLoading = false;
        });
      }
    }
  }
  
  // Simple function to launch the local fallback picker
  void _launchLocalFilePicker() async {
    try {
      Navigator.pop(context);
      final result = await widget.fallbackPicker();
      widget.onPickerResult(result);
    } catch (e) {
      Logger.e('Error launching local picker: $e');
      widget.onPickerResult({
        'action': 'canceled',
        'error': 'Error launching local picker: $e'
      });
    }
  }
  
  // Load the Google Picker HTML in a WebView
  Future<void> _loadWebView() async {
    try {
      Logger.d('Loading HTML from assets');
      final htmlContent = await rootBundle.loadString('assets/web/google_picker.html');
      
      if (!mounted) return;
      
      // Validate that we have the required values
      if (_accessToken == null || _accessToken!.isEmpty) {
        Logger.e('Access token is null or empty when trying to load WebView');
        setState(() {
          _errorMessage = 'Access token is missing. Please try logging in again.';
          _isLoading = false;
        });
        return;
      }
      
      if (widget.developerKey.isEmpty) {
        Logger.e('Developer key is empty');
        setState(() {
          _errorMessage = 'Developer key is missing. Please check your configuration.';
          _isLoading = false;
        });
        return;
      }
      
      // Replace placeholders in HTML - ADD DEBUGGING HERE
      final modifiedHtml = htmlContent
          .replaceAll('{{DEFAULT_ACCESS_TOKEN}}', _accessToken!)
          .replaceAll('{{DEFAULT_DEVELOPER_KEY}}', widget.developerKey)
          .replaceAll('{{DEFAULT_JS_CHANNEL}}', 'PickerChannel');
      
      // ADD THESE DEBUG LOGS
      Logger.d('Original HTML contains DEFAULT_ACCESS_TOKEN placeholder: ${htmlContent.contains('{{DEFAULT_ACCESS_TOKEN}}')}');
      Logger.d('Modified HTML contains DEFAULT_ACCESS_TOKEN placeholder: ${modifiedHtml.contains('{{DEFAULT_ACCESS_TOKEN}}')}');
      Logger.d('Modified HTML contains actual token: ${modifiedHtml.contains(_accessToken!.substring(0, 20))}');
      
      // Verify the replacement worked
      if (modifiedHtml.contains('{{DEFAULT_ACCESS_TOKEN}}')) {
        Logger.e('HTML placeholder replacement failed!');
        setState(() {
          _errorMessage = 'Failed to prepare HTML content. Please try again.';
          _isLoading = false;
        });
        return;
      }
      
      Logger.d('HTML content prepared with token: ${_accessToken!.substring(0, 20)}...');
      Logger.d('Developer key: ${widget.developerKey}');
      
      // Create controller with JavaScript channels
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              Logger.d('WebView started loading: $url');
            },
            onPageFinished: (String url) {
              Logger.d('WebView finished loading');
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            onWebResourceError: (WebResourceError error) {
              Logger.e('WebView error: ${error.description}');
              if (mounted) {
                setState(() {
                  _errorMessage = 'Failed to load Google Drive Picker: ${error.description}';
                  _isLoading = false;
                });
              }
            },
          ),
        )
        ..addJavaScriptChannel(
          'PickerChannel',
          onMessageReceived: (JavaScriptMessage message) {
            try {
              Logger.d('Received message from WebView: ${message.message}');
              final data = jsonDecode(message.message);
              widget.onPickerResult(data);
              if (mounted) {
                Navigator.pop(context);
              }
            } catch (e) {
              Logger.e('Error parsing picker result: $e');
            }
          },
        )
        ..addJavaScriptChannel(
          'LogChannel',
          onMessageReceived: (message) {
            Logger.d('WebView log: ${message.message}');
          },
        );
      
      // Load the HTML content
      await controller.loadHtmlString(modifiedHtml);
      
      if (mounted) {
        setState(() {
          _webViewController = controller;
        });
      }
      
      Logger.d('WebView controller initialized successfully');
      
    } catch (e) {
      Logger.e('Error initializing WebView: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize Google Drive Picker: $e';
          _isLoading = false;
        });
      }
    }
}
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dialog header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.drive_folder_upload, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Select a file from Google Drive',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      widget.onPickerResult({'action': 'canceled'});
                      Navigator.of(context).pop();
                    },
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            
            // Dialog body
            Expanded(
              child: Stack(
                children: [
                  // WebView
                  if (_accessToken != null && _webViewController != null && _errorMessage == null)
                    WebViewWidget(controller: _webViewController!),
                    
                  // Loading indicator
                  if (_isLoading && _errorMessage == null)
                    const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 20),
                          Text('Loading Google Drive Picker...'),
                        ],
                      ),
                    ),
                    
                  // Error message with fallback option
                  if (_errorMessage != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 20),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 30),
                            ElevatedButton(
                              onPressed: _launchLocalFilePicker,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Text('Use Local File Picker'),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: () {
                                widget.onPickerResult({'action': 'canceled'});
                                Navigator.of(context).pop();
                              },
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper class for authenticated HTTP requests
class GoogleAuthClient extends http.BaseClient {
  final String _accessToken;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
  }
}