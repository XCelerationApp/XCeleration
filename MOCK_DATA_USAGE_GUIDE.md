# Mock Data System Usage Guide

## Overview

The mock data system allows you to test the conflict resolution functionality without needing multiple devices. It generates realistic race scenarios with various types of conflicts.

## How to Use

### Option 1: Standalone Test Screen (Recommended)

- Navigate to `MockDataTestScreen` in your app
- This is a dedicated testing environment that doesn't require existing race data
- Provides a clean interface for testing both Simple and Complex modes

### Option 2: From Merge Conflicts Screen

- Open the Merge Conflicts screen
- If no data is loaded, you'll see a "Load Mock Data" button in the center
- If data is already loaded, look for the green floating action button with a science icon (🧪)
- Tap it to open the Mock Data Selector dialog

### 1. Select a Test Scenario

Choose from 5 preset scenarios:

#### **Clean Race Scenario** (8 runners)

- Perfect race with no conflicts
- All times confirmed and sequential
- Use this to test the UI with no conflicts

#### **Missing Times Scenario** (8 runners)

- One runner (place 4) has missing time (shows "TBD")
- Tests the missing time resolution flow
- Good for testing simple conflict resolution

#### **Extra Times Scenario** (8 runners)

- Extra time recorded at place 3 that needs removal
- Tests the extra time removal flow
- Demonstrates how to handle accidental double-taps

#### **Mixed Conflicts Scenario** (10 runners)

- Missing time at place 3
- Extra time at place 5
- Tests handling multiple conflict types simultaneously

#### **Complex Scenario** (12 runners)

- Multiple missing times (places 2-3)
- Multiple extra times (place 6)
- Most challenging scenario for testing

### 2. Load Mock Data

1. Select your desired scenario from the dropdown
2. Review the scenario details shown below the dropdown
3. Click "Load Mock Data" button
4. Wait for the success message

### 3. Test Conflict Resolution

- Use either Simple Mode or Complex Mode to resolve conflicts
- Test the different resolution approaches
- Compare performance and usability between modes

### 4. Clear Data (Optional)

- Click "Clear All Data" to reset everything
- Useful for starting fresh with different scenarios

## Testing Features

### What Each Scenario Tests

- **Missing Times**: TBD resolution, time input validation
- **Extra Times**: Record removal, place reassignment
- **Mixed**: Multiple conflict types, complex workflows
- **Complex**: Performance with multiple conflicts, edge cases
- **Clean**: UI behavior with no conflicts

### Mock Data Quality

- **Realistic Names**: Uses common first/last name combinations
- **Team Variety**: 5 different teams represented
- **Proper Bib Numbers**: 3-digit format (001, 002, etc.)
- **Valid Times**: Realistic race times with proper formatting
- **Conflict Accuracy**: Conflicts match real-world scenarios

### Integration with Simple Mode

The mock data works seamlessly with the Simple Conflict Resolution system:

- Load any scenario
- Toggle to Simple Mode using the "Compare Modes" button
- Test the streamlined conflict resolution process
- Compare with Complex Mode performance

## Technical Details

### Generated Data Structure

```dart
MockRaceData {
  runners: List<RunnerRecord>,      // Race participants
  timingData: TimingData,          // Timing records with conflicts
  scenarioName: String,            // Display name
  description: String              // Scenario description
}
```

### Conflict Types Created

- `RecordType.missingTime`: For TBD scenarios
- `RecordType.extraTime`: For removal scenarios
- `ConflictDetails`: Proper metadata for resolution

### Performance Testing

- Clean scenario: Baseline performance
- Complex scenario: Stress testing with 12 runners
- Mixed scenario: Real-world complexity simulation

## Benefits

### For Development

- **No Device Setup**: Test without multiple phones/tablets
- **Consistent Data**: Same scenarios every time
- **Edge Case Testing**: Scenarios designed to test limits
- **Rapid Iteration**: Quick loading of different scenarios

### For Testing

- **Comprehensive Coverage**: All conflict types represented
- **Realistic Data**: Names, teams, times match real races
- **Scalable**: Easy to modify runner counts
- **Repeatable**: Same results for consistent testing

### For Comparison

- **Mode Testing**: Compare Simple vs Complex approaches
- **Performance Analysis**: Measure resolution times
- **UX Evaluation**: Test user experience improvements
- **Validation**: Ensure both systems handle same data correctly

## Tips

1. **Start Simple**: Begin with Clean scenario to understand UI
2. **Progress Gradually**: Move from Missing → Extra → Mixed → Complex
3. **Test Both Modes**: Compare Simple and Complex resolution approaches
4. **Clear Between Tests**: Use "Clear All Data" for fresh starts
5. **Check Performance**: Notice speed differences between modes

## Troubleshooting

### If Loading Fails

- Check the error message in the snackbar
- Try clearing data first, then reload
- Restart app if persistent issues

### If Conflicts Don't Appear

- Ensure you selected a conflict scenario (not Clean)
- Check that data loaded successfully (green success message)
- Look for orange/red indicators in the UI

### If Resolution Doesn't Work

- Make sure you're in the correct mode (Simple vs Complex)
- Follow the on-screen instructions for resolution
- Try the comparison demo to see both approaches

## Future Enhancements

Potential improvements to the mock data system:

- Custom scenario builder
- Larger race scenarios (50+ runners)
- Time-based conflicts (duplicate times)
- Team-based scenarios
- Import/export of custom scenarios

---

The mock data system makes testing the conflict resolution functionality fast, reliable, and comprehensive without requiring multiple devices or complex setup procedures.
