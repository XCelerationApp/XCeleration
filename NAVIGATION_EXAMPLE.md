# Adding Mock Data Test Screen to Navigation

## Option 1: Add to Main Menu/Dashboard

```dart
// In your main screen or dashboard
ElevatedButton.icon(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MockDataTestScreen(),
      ),
    );
  },
  icon: const Icon(Icons.science),
  label: const Text('Test Conflict Resolution'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.green,
    foregroundColor: Colors.white,
  ),
)
```

## Option 2: Add to App Drawer

```dart
// In your app drawer
ListTile(
  leading: const Icon(Icons.science, color: Colors.green),
  title: const Text('Mock Data Testing'),
  subtitle: const Text('Test conflict resolution'),
  onTap: () {
    Navigator.pop(context); // Close drawer
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MockDataTestScreen(),
      ),
    );
  },
),
```

## Option 3: Add to Settings/Debug Menu

```dart
// In settings or debug menu
Card(
  child: ListTile(
    leading: Icon(Icons.science, color: Colors.green.shade600),
    title: const Text('Conflict Resolution Testing'),
    subtitle: const Text('Test with mock race data'),
    trailing: const Icon(Icons.arrow_forward_ios),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MockDataTestScreen(),
      ),
    ),
  ),
),
```

## Option 4: Add as Debug Action (Development Only)

```dart
// Only show in debug mode
if (kDebugMode)
  FloatingActionButton.extended(
    onPressed: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MockDataTestScreen(),
      ),
    ),
    icon: const Icon(Icons.science),
    label: const Text('Mock Data'),
    backgroundColor: Colors.green,
  ),
```

## Import Statement

Don't forget to add the import at the top of your file:

```dart
import 'package:xceleration/coach/merge_conflicts/screen/mock_data_test_screen.dart';
```

## Usage Recommendation

For development and testing purposes, **Option 4** (debug-only FAB) is recommended as it:

- Only appears in debug builds
- Doesn't clutter the production UI
- Provides quick access during development
- Can be easily removed for production builds

For production testing or demo purposes, **Option 1** or **Option 2** work well depending on your app's navigation structure.
