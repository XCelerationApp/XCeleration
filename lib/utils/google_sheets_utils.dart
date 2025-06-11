import 'dart:async';
import 'package:flutter/material.dart';
import 'google_sheets_service.dart';

/// Utility class for Google Sheets operations
/// Uses GoogleSheetsService which indirectly handles authentication via GoogleAuthService
/// 
/// This class provides static methods that delegate to GoogleSheetsService
/// It exists for compatibility with existing code that uses GoogleSheetsUtils
class GoogleSheetsUtils {
  // Use the singleton instance of GoogleSheetsService
  static final GoogleSheetsService _sheetsService = GoogleSheetsService.instance;
  
  /// Create a Google Sheet and return a Uri that can be used to view or share it
  /// This is the primary method used by other components in the app
  /// Delegates to GoogleSheetsService.createSheetAndGetUri
  static Future<Uri?> createSheetAndGetUri({
    required BuildContext context,
    required String title,
    required List<List<dynamic>> data,
  }) async {
    return await _sheetsService.createSheetAndGetUri(
      context: context,
      title: title,
      data: data,
    );
  }
  
  /// Create a Google Sheet with the given title and data
  /// Delegates to GoogleSheetsService.createSheet
  static Future<String?> createSheet({
    required BuildContext context,
    required String title,
    required List<List<dynamic>> data,
  }) async {
    return await _sheetsService.createSheet(
      context: context, 
      title: title, 
      data: data,
    );
  }
  
  /// Construct a sharing URL directly from the spreadsheet ID
  /// Delegates to GoogleSheetsService.constructSharingUrl
  static String constructSharingUrl(String spreadsheetId) {
    return _sheetsService.constructSharingUrl(spreadsheetId);
  }
}
