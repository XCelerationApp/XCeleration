# Mode Switching Guide - Conflict Resolution

## Overview
The merge conflicts screen now supports easy switching between **Simple Mode** and **Complex Mode** for conflict resolution, making it easy to choose the approach that works best for your needs.

## How to Switch Modes

### 1. App Bar Toggle Button
- **Location**: Top-right corner of the merge conflicts screen
- **Visual**: Shows current mode with toggle icon
- **Action**: Tap to switch between modes instantly

### 2. Quick Access Floating Action Button
- **Location**: Top floating action button (above mock data button)
- **Visual**: 
  - 🟢 **Green with lightbulb icon** = Simple Mode
  - 🔵 **Blue with settings icon** = Complex Mode
- **Action**: Tap to toggle mode instantly

### 3. Mode Indicator Card
- **Location**: Below the title, above the conflict list
- **Visual**: Colored card showing current mode and description
- **Information**: Shows which mode is active and what it does

## Mode Differences

### 🟢 Simple Mode
- **Best for**: Quick conflict resolution, beginners, straightforward conflicts
- **Features**:
  - Streamlined interface with direct controls
  - One conflict at a time
  - Immediate resolution without complex chunking
  - Clean, minimal UI
- **When to use**: When you want fast, direct conflict resolution

### 🔵 Complex Mode  
- **Best for**: Advanced users, complex conflicts, detailed control
- **Features**:
  - Advanced chunk-based conflict management
  - Detailed runner and timing information
  - Batch conflict resolution
  - Full control over all aspects
- **When to use**: When you need detailed control over the resolution process

## Usage Tips

1. **Start Simple**: Try Simple Mode first for most conflicts
2. **Switch Anytime**: You can toggle between modes at any time during conflict resolution
3. **Mode Persistence**: Your mode choice is remembered during the session
4. **Visual Feedback**: The interface colors and icons change to match the selected mode
5. **Test Both**: Use the "Compare Modes" button to see both modes side-by-side

## API Methods (for developers)

```dart
// Toggle between modes
controller.toggleMode();

// Set specific mode
controller.setSimpleMode(true);  // Switch to simple
controller.setSimpleMode(false); // Switch to complex

// Check current mode
bool isSimple = controller.useSimpleMode;
String modeName = controller.currentModeString;
String description = controller.modeDescription;
```

## Testing

The mode switching works with all mock data scenarios:
- Clean Race (no conflicts)
- Missing Times
- Extra Times  
- Mixed Conflicts
- Complex Scenarios

Load any mock data scenario and switch between modes to see how each handles the same conflicts differently. 