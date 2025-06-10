import 'package:flutter/foundation.dart';

/// A test-specific implementation of debugPrint that prevents UI-related errors
/// in unit tests by capturing logs instead of showing UI components
class TestLogger {
  /// The original debugPrint function that we'll restore later
  static DebugPrintCallback? _originalDebugPrint;
  
  /// Flag to track if we've set up the logger
  static bool _isSetUp = false;
  
  /// List of captured logs for verification
  static List<String> capturedLogs = [];
  
  /// Sets up the test logger by patching debugPrint
  static void setUp() {
    if (_isSetUp) return;
    _isSetUp = true;
    
    // Store the original debugPrint
    _originalDebugPrint = debugPrint;
    
    // Override debugPrint with our test version
    debugPrint = _testPrint;
    
    // Clear any previous logs
    capturedLogs = [];
    
    print('[TEST] Test logger configured');
  }
  
  /// A test version of debugPrint that doesn't trigger UI operations
  static void _testPrint(String? message, {int? wrapWidth}) {
    if (message == null) return;
    
    // Add to captured logs
    capturedLogs.add(message);
    
    // Print with TEST prefix for clarity in test output
    print('[TEST LOG] $message');
  }
  
  /// Resets the test logger state
  static void reset() {
    capturedLogs = [];
  }
  
  /// Tears down the test logger by restoring the original debugPrint
  static void tearDown() {
    if (!_isSetUp) return;
    
    if (_originalDebugPrint != null) {
      debugPrint = _originalDebugPrint!;
    }
    
    _isSetUp = false;
  }
}
