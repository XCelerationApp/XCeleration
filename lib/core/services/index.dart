/// Central export file for core services
/// This provides clean imports for all services across the app
library;

// Core Services
export 'service_locator.dart';
export 'event_bus.dart';

// Device & Connection Services
export 'device_connection_service.dart';
export 'nearby_connections.dart';
export 'permissions_service.dart';

// Google Services
export 'google_service.dart';

// UI Services
export 'tutorial_manager.dart';
export 'splash_screen.dart';
