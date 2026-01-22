# TimeTrack

A macOS menu bar application for automatic time tracking with AI-powered activity categorization.

## Features

- **Automatic Window Tracking**: Tracks the currently focused application and window title
- **Project-based Organization**: Organize your time into customizable projects
- **Voice Input**: Use voice commands to quickly categorize activities (Cmd+Shift+T)
- **AI Categorization**: Leverages Ollama for intelligent automatic activity categorization
- **Daily Reports**: View daily time summaries with visual charts
- **Quick Picker**: Fast project selection with Cmd+Shift+M
- **Browser URL Detection**: Captures URLs from Safari, Chrome, Arc, and other browsers

## Requirements

- macOS 14.0 or later
- Xcode 15+ (for building)
- Swift 5.9+
- [Ollama](https://ollama.ai) (optional, for AI categorization)

## Installation

### From Source

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/TimeTrack.git
   cd TimeTrack
   ```

2. Build using Swift Package Manager:
   ```bash
   swift build -c release
   ```

3. Or open in Xcode:
   ```bash
   open TimeTrack.xcodeproj
   ```
   Then build and run (Cmd+R).

## Permissions

TimeTrack requires the following macOS permissions:

- **Accessibility**: Required to read window titles from other applications
- **Speech Recognition**: Required for voice input feature
- **Automation**: Optional, for extracting browser URLs

Grant these permissions in **System Settings > Privacy & Security**.

## Usage

### Menu Bar

The app lives in your menu bar showing:
- Clock icon when tracking is active
- Current project indicator (colored dot + name)
- Mic icon when voice input is active

Click the menu bar icon to:
- See current activity details
- Select a project manually
- View mini stats
- Access settings and reports

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+Shift+T | Toggle voice input |
| Cmd+Shift+M | Open quick project picker |

### Voice Commands

Activate voice input with Cmd+Shift+T, then say the project name to categorize your current activity. The app will automatically stop listening after you speak.

### Projects

Create and manage projects in Settings (accessible from the menu bar). Each project has:
- Name
- Color (for visual identification)
- Category rules (for automatic matching)

## Architecture

```
TimeTrack/
├── App/
│   ├── TimeTrackApp.swift    # Main app entry point
│   ├── AppState.swift        # Central state management
│   └── AppDelegate.swift     # App lifecycle
├── Models/
│   ├── Project.swift         # Project model
│   ├── Activity.swift        # Activity record
│   ├── CategoryRule.swift    # Auto-categorization rules
│   └── TimeEntry.swift       # Time entry aggregation
├── Services/
│   ├── WindowTracker.swift   # Monitors active windows
│   ├── ActivityManager.swift # Manages activity recording
│   ├── CategoryEngine.swift  # Handles categorization logic
│   ├── OllamaService.swift   # AI integration
│   ├── SpeechService.swift   # Voice recognition
│   └── HotkeyService.swift   # Global hotkeys
├── Persistence/
│   ├── Database.swift        # SQLite database setup
│   ├── ActivityStore.swift   # Activity CRUD
│   └── ProjectStore.swift    # Project CRUD
└── Views/
    ├── MenuBar/              # Menu bar UI components
    ├── Settings/             # Settings views
    └── Reports/              # Report views
```

## Dependencies

- [GRDB.swift](https://github.com/groue/GRDB.swift) - SQLite database wrapper

## License

MIT
