import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:xceleration/core/utils/logger.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:xceleration/core/components/dialog_utils.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:xceleration/utils/file_utils.dart';
import 'google_auth_service.dart';
import 'google_sheets_service.dart';


/// A service that handles picking files from Google Drive using the Google Picker API
class GooglePickerService {
  static GooglePickerService? _instance;
  static GooglePickerService get instance => _instance ??= GooglePickerService._();
  
  final GoogleAuthService _authService = GoogleAuthService.instance;
  final GoogleSheetsService _sheetsService = GoogleSheetsService.instance;

  // Google Picker API constants
  static String get _apiKey => dotenv.env['GOOGLE_API_KEY'] ?? '';
  static String get _developerKey => _apiKey;
  static String get _appId => dotenv.env['GOOGLE_APP_ID'] ?? '';
  static String get _webClientId => dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';
  
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
          clientId: _webClientId,
          developerKey: _developerKey,
          appId: _appId,
          fallbackPicker: () => FileUtils.pickLocalSpreadsheetFile().then((result) {
            if (result != null) {
              return {
                'action': 'picked',
                'data': result,
                'isLocalFile': true
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
  
  /// Opens a file picker that allows the user to select a file from Google Drive
  /// Returns the selected file as a temporary file downloaded to the device
  /// Only allows selection of spreadsheet files (Google Sheets, CSV, XLSX)
  Future<File?> pickGoogleDriveFile(BuildContext context) async {
    try {
      // Directly proceed with Google Drive flow without showing the source selection dialog
      Logger.d('Proceeding directly with Google Drive picker');

      // Get access token for Google Drive
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
        if (pickerResult != null && pickerResult['action'] == 'canceled') {
          Logger.d('User canceled Google Drive picker');
        } else {
          Logger.e('Error picking file: $pickerResult');
        }
        return null;
      }

      final doc = pickerResult['data'] as Map<String, dynamic>?;
      if (doc == null) {
        Logger.d('No documents selected');
        return null;
      }

      final fileId = doc['id'] as String?;
      final fileName = doc['name'] as String?;
      final mimeType = doc['mimeType'] as String?;
      final url = doc['url'] as String?;

      Logger.d('Selected file: id=$fileId, name=$fileName, mimeType=$mimeType, url=$url');

      if (fileId == null || fileName == null || mimeType == null) {
        Logger.d('Invalid document data: $doc');
        return null;
      }


      if (!_isSupportedFileType(mimeType, fileName)) {
        Logger.d('Unsupported file type: $fileName');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File format not supported. Please select a spreadsheet file (XLSX, CSV, XLS)')),
          );
        }
        return null;
      }

      
      if (pickerResult['isLocalFile'] == true) {
        return File(pickerResult['data']['path']);
      }

      try {
        // For Google Sheets, use the dedicated Google Sheets Service
        if (mimeType == 'application/vnd.google-apps.spreadsheet') {
          Logger.d('Using GoogleSheetsService for downloading Google Sheet');
          if (context.mounted) {
            // Extract URL from pickerResult if available
            String? sheetUrl = pickerResult['data']?['url'] as String?;
            Logger.d('Passing URL to GoogleSheetsService: $sheetUrl');
            
            return await _sheetsService.downloadGoogleSheet(
              fileId: fileId,
              fileName: fileName,
              url: sheetUrl,  // Pass the URL to give more download options
              context: context,
            );
          }
          return null;
        }
        
        // Download other file types with loading dialog
        if (context.mounted) {
          final tempFile = await DialogUtils.executeWithLoadingDialog<File?>(
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
  
  /// Downloads the specified file from Google Drive or exports via public URL for Google Sheets
  /// Downloads a regular (non-Google Sheet) file from Google Drive using the fileId and accessToken
  /// Google Sheet downloads are handled by GoogleSheetsService.downloadGoogleSheet
  Future<File?> _downloadFile(String fileId, String accessToken, String fileName) async {
    Logger.d('Downloading file: $fileId, fileName: $fileName');
    
    try {
      // Regular file download using API and auth
      final authClient = GoogleAuthClient(accessToken);
      
      try {
        Logger.d('Downloading regular file');
        // For regular files, use the standard download method
        final response = await authClient.get(
          Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId?alt=media'),
        );
        
        if (response.statusCode != 200) {
          Logger.d('Download failed with status ${response.statusCode}: ${response.body}');
          throw Exception('Failed to download file: ${response.statusCode} ${response.body}');
        }
        
        // Create a temporary file
        final directory = await getTemporaryDirectory();
        String filePath = '${directory.path}/$fileName';
        
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        Logger.d('File downloaded successfully to $filePath');
        return file;
      } catch (e) {
        Logger.d('Error downloading file: $e');
        return null;
      } finally {
        authClient.close();
      }
    } catch (e) {
      Logger.d('Error in _downloadFile: $e');
      return null;
    }
  }
  
  /// Check if the file type is supported
  bool _isSupportedFileType(String mimeType, String fileName) {
    // Support Google Sheets
    if (mimeType == 'application/vnd.google-apps.spreadsheet') {
      return true;
    }
    
    // Support Excel files
    if (mimeType.contains('excel') || 
        mimeType == 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' || 
        mimeType == 'application/vnd.ms-excel') {
      return true;
    }
    
    // Support CSV files
    if (mimeType == 'text/csv' || fileName.toLowerCase().endsWith('.csv')) {
      return true;
    }
    
    // Support Excel files by extension
    if (fileName.toLowerCase().endsWith('.xlsx') || 
        fileName.toLowerCase().endsWith('.xls') || 
        fileName.toLowerCase().endsWith('.ods')) {
      return true;
    }
    
    // Support Google Sheets direct links
    if (fileName.toLowerCase().endsWith('.gsheet') || fileName.toLowerCase().endsWith('.gsf')) {
      return true;
    }
    
    return false;
  }
}

/// A dialog widget that displays the Google Picker in a WebView
class GooglePickerDialog extends StatefulWidget {
  /// Callback function when a file is selected or the picker is closed
  final Function(Map<String, dynamic>?) onPickerResult;
  
  /// Google API client ID
  final String clientId;

  /// Google API developer key
  final String developerKey;

  /// Google API app ID
  final String appId;
  
  /// Fallback local file picker function
  final Future<Map<String, dynamic>?> Function() fallbackPicker;

  const GooglePickerDialog({
    required this.onPickerResult,
    required this.clientId,
    required this.developerKey,
    required this.appId,
    required this.fallbackPicker,
    super.key,
  });

  @override
  State<GooglePickerDialog> createState() => _GooglePickerDialogState();
}

class _GooglePickerDialogState extends State<GooglePickerDialog> {
  WebViewController? _webViewController;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _timeoutTimer;
  
  @override
  void initState() {
    super.initState();
    _loadWebView();
    
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
      
      if (widget.developerKey.isEmpty) {
        Logger.e('Developer key is empty');
        setState(() {
          _errorMessage = 'Developer key is missing. Please check your configuration.';
          _isLoading = false;
        });
        return;
      }
      
      
      // Create WebViewController with all settings at once
      final controller = WebViewController();
      
      // Set JavaScript mode
      controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      
      // Add JavaScript channels
      controller.addJavaScriptChannel(
        'PickerChannel',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            Logger.d('📩 Received message from WebView: ${message.message}');
            final data = jsonDecode(message.message);
            
            // Check if this is an error message
            if (data['action'] == 'error') {
              Logger.e('Error from picker: ${data['message']}');
              if (mounted) {
                setState(() {
                  _errorMessage = data['message'] ?? 'Unknown error from picker';
                  _isLoading = false;
                });
              }
              return;
            }
            
            widget.onPickerResult(data);
            if (mounted) {
              Navigator.pop(context);
            }
          } catch (e) {
            Logger.e('Error parsing picker result: $e');
          }
        },
      );
      
      controller.addJavaScriptChannel(
        'LogChannel',
        onMessageReceived: (message) {
          Logger.d('🌐 WebView: ${message.message}');
        },
      );
      
      // Set navigation delegate
      controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            Logger.d('🌐 WebView started loading: $url');
            
          },
          onPageFinished: (String url) {
              Logger.d('🌐 WebView finished loading');
              
              // Inject diagnostic code to check if Google API loaded correctly
              controller.runJavaScript('''
                if (window.LogChannel) {
                  LogChannel.postMessage('[STATUS] Page loaded, checking APIs');
                  LogChannel.postMessage('[STATUS] gapi defined: ' + (typeof gapi !== 'undefined'));
                  LogChannel.postMessage('[STATUS] google defined: ' + (typeof google !== 'undefined'));
                  LogChannel.postMessage('[STATUS] google.picker defined: ' + 
                    (typeof google !== 'undefined' && typeof google.picker !== 'undefined'));
                }
              ''');
              // Set the variables using the new method
              controller.runJavaScript('''
                if (window.setPickerVariables) {
                  window.setPickerVariables("${widget.developerKey}", "${widget.clientId}", "${widget.appId}", "PickerChannel");
                } else {
                  console.error('setPickerVariables function not found');
                }
              ''');
              
              Logger.d('WebView variables set via setPickerVariables');
              
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            onWebResourceError: (WebResourceError error) {
              Logger.e('🚫 WebView error: ${error.description} (${error.errorCode})');
              if (mounted) {
                setState(() {
                  _errorMessage = 'Failed to load Google Drive Picker: ${error.description}';
                  _isLoading = false;
                });
              }
            },
          ),
        );
      
      // Load the HTML content
      await controller.loadHtmlString(htmlContent, baseUrl: 'http://localhost');
      
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
    // Use a completely full-screen dialog with no margins
    return Material(
      type: MaterialType.transparency,
      
      // GestureDetector at the root level to detect taps outside the WebView
      child: GestureDetector(
        // This will handle taps on the background (outside the WebView)
        onTap: () {
          widget.onPickerResult({'action': 'canceled'});
          Navigator.of(context).pop();
        },
        child: Container(
          color: Colors.transparent, // Important for the GestureDetector to detect taps
          width: double.infinity,
          height: double.infinity,
          // Center the WebView in the middle of the screen
          child: Center(
            child: Stack(
              children: [
                // Show loading indicator when WebView is not ready
                if (_isLoading || _webViewController == null)
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading Google Drive Picker...'),
                      ],
                    ),
                  ),
                  
                // Show error message if there is one
                if (_errorMessage != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _launchLocalFilePicker,
                            child: const Text('Use Local File Picker'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                // Show WebView when controller is ready
                if (_webViewController != null && !_isLoading && _errorMessage == null)
                  GestureDetector(
                    // Stop the tap from propagating to the outer GestureDetector
                    onTap: () {}, // Empty function to catch the tap
                    child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15.0),
                            color: Colors.transparent,
                          ),
                          clipBehavior: Clip.antiAlias,
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.9,
                            maxHeight: MediaQuery.of(context).size.height * 0.55,
                          ),
                          child: WebViewWidget(controller: _webViewController!),
                        ),
                  ),
              ],
            ),
          ),
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