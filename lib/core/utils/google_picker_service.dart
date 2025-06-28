import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/components/dialog_utils.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'google_auth_service.dart';
import 'google_sheets_service.dart';
import 'google_drive_service.dart';

/// A service that handles picking files from Google Drive using the Google Picker API
class GooglePickerService {
  static GooglePickerService? _instance;
  static GooglePickerService get instance =>
      _instance ??= GooglePickerService._();

  final GoogleAuthService _authService = GoogleAuthService.instance;
  final GoogleSheetsService _sheetsService = GoogleSheetsService.instance;
  final GoogleDriveService _driveService = GoogleDriveService.instance;

  // Google Picker API constants
  static String get _apiKey => dotenv.env['GOOGLE_WEB_API_KEY'] ?? '';
  static String get _developerKey => _apiKey;
  static String get _appId => dotenv.env['GOOGLE_APP_ID'] ?? '';

  GooglePickerService._();

  /// Static method to pick a file from Google Drive
  /// Returns the result of the picker operation
  static Future<Map<String, dynamic>?> showPicker(
      {required BuildContext context}) async {
    Logger.d('Opening Google Picker dialog');
    Logger.d('Context mounted: ${context.mounted}');
    try {
      final instance = GooglePickerService.instance;
      final accessToken = await instance._authService.webAccessToken;
      if (accessToken == null) {
        return {'action': 'error', 'message': 'Google Authentication Failed'};
      }
      if (!context.mounted) {
        return {'action': 'error'};
      }

      return showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => GooglePickerDialog(
          accessToken: accessToken,
          developerKey: _developerKey,
          appId: _appId,
        ),
      );
    } catch (e) {
      Logger.e('Error showing picker dialog: $e');
      return {'action': 'error'};
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
      final accessToken = await _authService.webAccessToken;
      if (accessToken == null) {
        Logger.e('Failed to get access token');
        if (context.mounted) {
          DialogUtils.showErrorDialog(context,
              message: 'Failed to authenticate with Google Drive');
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
          if (context.mounted) {
            String message = 'Error in Picking Spreadsheet from Google Drive';
            if (pickerResult != null && pickerResult['message'] != null) {
              message += ': ${pickerResult['message']}';
            }
            DialogUtils.showErrorDialog(context, message: message);
          }
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

      Logger.d('Selected file: id=$fileId, name=$fileName, mimeType=$mimeType');

      if (fileId == null || fileName == null || mimeType == null) {
        Logger.d('Invalid document data: $doc');
        return null;
      }

      if (!_isSupportedFileType(mimeType, fileName)) {
        Logger.d('Unsupported file type: $fileName');
        if (context.mounted) {
          DialogUtils.showErrorDialog(
            context,
            message:
                'File format not supported. Please select a spreadsheet file (XLSX, CSV, XLS, or Google Sheet).',
          );
        }
        return null;
      }

      try {
        // For Google Sheets, use the dedicated Google Sheets Service
        if (mimeType == 'application/vnd.google-apps.spreadsheet') {
          Logger.d('Using GoogleSheetsService for downloading Google Sheet');
          if (context.mounted) {
            return await _sheetsService.downloadGoogleSheet(
              fileId: fileId,
              fileName: fileName,
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
            operation: () => _driveService.downloadFile(fileId, fileName),
            allowCancel: true,
          );

          if (tempFile != null) {
            return tempFile;
          }
        }

        return null;
      } catch (e) {
        Logger.e('Error downloading file: $e');
        if (context.mounted) {
          DialogUtils.showErrorDialog(
            context,
            message:
                'Download Failed: Could not download the selected file. Please try again.',
          );
        }
        return null;
      }
    } catch (e) {
      Logger.e('Error in picker process: $e');
      if (context.mounted) {
        DialogUtils.showErrorDialog(
          context,
          message:
              'An error occurred while selecting the file. Please try again.',
        );
      }
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
        mimeType ==
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ||
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
    if (fileName.toLowerCase().endsWith('.gsheet') ||
        fileName.toLowerCase().endsWith('.gsf')) {
      return true;
    }

    return false;
  }
}

/// A dialog widget that displays the Google Picker in a WebView
class GooglePickerDialog extends StatefulWidget {
  /// Function to get Google OAuth2 access token
  final String accessToken;

  /// Google API developer key
  final String developerKey;

  /// Google API app ID
  final String appId;

  const GooglePickerDialog({
    required this.accessToken,
    required this.developerKey,
    required this.appId,
    super.key,
  });

  @override
  State<GooglePickerDialog> createState() => _GooglePickerDialogState();
}

class _GooglePickerDialogState extends State<GooglePickerDialog> {
  WebViewController? _webViewController;
  bool _isLoading = true;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _loadWebView();

    // Set a timeout to show fallback if picker doesn't load in 15 seconds
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _isLoading) {
        Navigator.of(context)
            .pop({'action': 'error', 'message': 'Google Drive Picker Timeout'});
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _webViewController = null;
    super.dispose();
  }

  Future<void> _loadWebView() async {
    try {
      Logger.d('Loading HTML from assets');
      final pickerUrl = dotenv.env['GOOGLE_PICKER_URL'];
      if (pickerUrl == null) {
        Logger.e('GOOGLE_PICKER_URL is not set');
        Navigator.of(context).pop(
            {'action': 'error', 'message': 'Google Authentication Failed'});
        return;
      }

      if (!mounted) return;

      // Validate that we have the required values
      if (widget.accessToken.isEmpty) {
        Logger.e('Access token is null or empty when trying to load WebView');
        Navigator.of(context).pop(
            {'action': 'error', 'message': 'Google Authentication Failed'});
        return;
      }

      if (widget.developerKey.isEmpty) {
        Logger.e('Developer key is empty');
        Navigator.of(context).pop(
            {'action': 'error', 'message': 'Google Authentication Failed'});
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
            Logger.d('Received message from WebView: ${message.message}');
            final data = jsonDecode(message.message);

            // Check if this is an error message
            if (data['action'] == 'error') {
              Logger.e('Error from picker: ${data['message']}');
              Navigator.of(context).pop({
                'action': 'error',
                'message': data['type'] ?? 'Unknown Error'
              });
              return;
            }

            Navigator.of(context).pop(data);
          } catch (e) {
            Logger.e('Error parsing picker result: $e');
            Navigator.of(context)
                .pop({'action': 'error', 'message': 'Unknown Error'});
          }
        },
      );

      controller.addJavaScriptChannel(
        'LogChannel',
        onMessageReceived: (message) {
          Logger.d('WebView: ${message.message}');
        },
      );

      // Set navigation delegate
      controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            Logger.d('WebView started loading: $url');
          },
          onPageFinished: (String url) {
            Logger.d('WebView finished loading');
            Logger.d('Context mounted: ${context.mounted}');

            // Set the variables using the new method
            controller.runJavaScript('''
              if (window.setPickerVariables) {
                window.setPickerVariables("${widget.developerKey}", "${widget.accessToken}", "${widget.appId}", "PickerChannel");
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
            Logger.e(
                'WebView error: ${error.description} (${error.errorCode})');
            Navigator.of(context).pop({
              'action': 'error',
              'message': 'Failed to load Google Drive Picker'
            });
          },
        ),
      );

      // Load the HTML content
      await controller.loadRequest(Uri.parse(pickerUrl));

      if (mounted) {
        setState(() {
          _webViewController = controller;
        });
      }

      Logger.d('WebView controller initialized successfully');
    } catch (e) {
      Logger.e('Error initializing WebView: $e');
      if (mounted) {
        Navigator.of(context).pop({
          'action': 'error',
          'message': 'Failed to initialize Google Drive Picker: $e'
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use a completely full-screen dialog with no margins
    return Dialog(
        backgroundColor: Colors.transparent,
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
            child: Column(children: [
              // Show loading indicator when WebView is not ready
              if (_isLoading || _webViewController == null)
                const Center(child: CircularProgressIndicator()),

              // Show WebView when controller is ready
              if (_webViewController != null && !_isLoading)
                Container(
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
                )
            ])));
  }
}
