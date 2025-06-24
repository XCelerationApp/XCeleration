# Dependency Optimization Recommendations

## Current Dependencies Analysis

### **Potentially Redundant Dependencies**

1. **WebView Dependencies (Choose One)**
   ```yaml
   # Current - using both
   webview_flutter: ^4.13.0
   flutter_inappwebview: ^6.1.5
   
   # Recommendation - choose one
   flutter_inappwebview: ^6.1.5  # More feature-rich
   ```

2. **Excel vs CSV (Simplify)**
   ```yaml
   # Current
   csv: ^5.0.2
   excel: ^2.0.3
   
   # Recommendation - if only basic spreadsheet operations
   csv: ^5.0.2  # Remove excel if CSV is sufficient
   ```

3. **Portal Package**
   ```yaml
   # Current
   flutter_portal: ^1.1.4
   
   # Question: Is this actually being used? Could be replaced with Overlay
   ```

### **Dependencies to Keep (Essential)**

```yaml
# Core Flutter & State Management
flutter: sdk: flutter
provider: ^6.0.0

# Database & Storage
sqflite: ^2.2.8+4
shared_preferences: ^2.2.2
path_provider: ^2.0.15

# Network & API
http: ^1.2.0
googleapis: ^11.0.0
google_sign_in: ^6.1.6

# Device Features
flutter_nearby_connections: ^1.1.2
permission_handler: ^11.1.0
geolocator: ^13.0.2

# UI & UX
flutter_svg: ^2.0.9
flutter_spinkit: ^5.2.1
flutter_slidable: ^3.0.1

# Utilities
intl: ^0.18.0
uuid: ^4.2.2
crypto: ^3.0.3
```

### **Bundle Size Impact**

| Package | Estimated Size | Necessity | Recommendation |
|---------|---------------|-----------|----------------|
| `excel` | ~2MB | Low | Remove if CSV sufficient |
| `flutter_inappwebview` | ~8MB | Medium | Keep if webview needed |
| `webview_flutter` | ~4MB | Low | Remove (redundant) |
| `flutter_portal` | ~100KB | Unknown | Audit usage |
| `pdf` | ~3MB | Medium | Keep if PDF generation needed |
| `googleapis` | ~5MB | High | Keep (core feature) |

### **Optimization Recommendations**

#### **Phase 1: Safe Removals**
1. Remove `webview_flutter` (keep `flutter_inappwebview`)
2. Audit and potentially remove `flutter_portal`
3. Consider removing `excel` if CSV is sufficient

#### **Phase 2: Feature Analysis**
1. **PDF Generation**: Is this heavily used? Consider server-side generation
2. **Google APIs**: Consolidate to only needed scopes
3. **Barcode Scanning**: Consider if camera package could handle this

#### **Phase 3: Alternative Solutions**
1. **Color Picker**: Could be replaced with custom implementation
2. **Dropdown**: Could use standard Flutter widgets
3. **WebView**: Consider if really needed or can be external browser

### **Estimated Size Reduction**

- **Conservative**: 5-8MB (remove redundant packages)
- **Aggressive**: 15-20MB (remove optional features)
- **Code Reduction**: 20-30% (consolidate similar functionality)

### **Migration Strategy**

1. **Audit Usage**: Search codebase for each package usage
2. **Create Alternatives**: For packages being removed
3. **Test Thoroughly**: Ensure no functionality is lost
4. **Monitor Bundle Size**: Track improvements

### **Recommended pubspec.yaml Changes**

```yaml
dependencies:
  # Core
  flutter: {sdk: flutter}
  provider: ^6.0.0
  
  # Data & Storage
  sqflite: ^2.2.8+4
  shared_preferences: ^2.2.2
  path_provider: ^2.0.15
  csv: ^5.0.2
  
  # Network
  http: ^1.2.0
  
  # Google Services (consolidated)
  googleapis: ^11.0.0
  google_sign_in: ^6.1.6
  
  # Device Features
  flutter_nearby_connections: ^1.1.2
  permission_handler: ^11.1.0
  geolator: ^13.0.2
  geocoding: ^2.1.1
  audioplayers: ^6.1.0
  
  # UI Components
  flutter_svg: ^2.0.9
  flutter_spinkit: ^5.2.1
  flutter_slidable: ^3.0.1
  flutter_colorpicker: ^1.0.3  # If needed
  
  # Utilities
  intl: ^0.18.0
  uuid: ^4.2.2
  crypto: ^3.0.3
  collection: ^1.17.0
  
  # Optional (evaluate need)
  # pdf: ^3.10.7
  # flutter_inappwebview: ^6.1.5
  # barcode_scan2: ^4.1.0
  
  # Development & Error Tracking
  sentry_flutter: ^8.14.2
  package_info_plus: ^8.3.0
  flutter_dotenv: ^5.1.0
```

### **Next Steps**

1. **Usage Audit**: Run dependency analysis
2. **Feature Mapping**: Map each package to specific features
3. **User Impact Analysis**: Determine which features can be simplified
4. **Implementation Plan**: Create migration timeline 