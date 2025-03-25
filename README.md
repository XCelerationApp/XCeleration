# XCelerate - Race Timing and Management App

<img src="assets/icon/XCelerate_icon.png" alt="XCelerate Logo" width="120"/>

XCelerate is a comprehensive race timing and management application built with Flutter, designed for cross-country, track, and other running events. The app provides tools for both coaches and race assistants to streamline the entire race management process.

## Features

- **Race Timing** - Accurate timing of participants with intuitive controls
- **Bib Number Recognition** - Record bib numbers manually or through camera recognition
- **Results Management** - View, analyze, and share race results easily
- **Multi-device Synchronization** - Connect multiple devices for coordinated race timing
- **Coach & Assistant Modes** - Specialized interfaces for different race staff roles
- **Race Data Import/Export** - Support for CSV and Excel files
- **Results Sharing** - Share results via multiple channels

## Development Notes

### Prerequisites

- Flutter SDK ^3.5.4
- Dart SDK (latest stable)
- Android Studio / Xcode for mobile deployment
- Python (for ML-based bib number recognition)

### Setup

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── assistant/           # Assistant-specific features
│   ├── bib_number_recorder/
│   └── race_timer/
├── coach/               # Coach-specific features
│   ├── flows/           # Different coach workflows
│   ├── race_screen/     # Race management screens
│   └── results_screen/  # Results viewing and analysis
├── core/                # Shared core functionality
│   ├── components/      # Reusable UI components
│   ├── models/          # Data models
│   ├── services/        # Backend services
│   └── theme/           # App styling
└── server/              # Flask server for ML functionality
```

## Technologies Used

- **Flutter** - UI framework
- **Provider** - State management
- **SQLite** - Local database storage
- **Flask** - Python server for ML integration
- **TensorFlow/ML** - For bib number recognition

## License

This project is proprietary and confidential. Unauthorized copying, distribution, or deployment of this software is strictly prohibited.

## Contact

For support or inquiries, please contact [your-email@example.com](mailto:your-email@example.com).
