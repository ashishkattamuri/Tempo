# Tempo

A smart calendar assistant for iOS that manages your schedule like a personal assistant.

![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Features

### Smart Task Categories
Organize tasks by priority with intelligent handling:
- **Non-Negotiable** - Fixed appointments that never move
- **Identity Habits** - Daily practices that can compress but never disappear
- **Flexible Tasks** - Work that can be rescheduled
- **Optional Goals** - Nice-to-haves that defer when needed

### Intelligent Conflict Resolution
When tasks overlap, Tempo suggests smart resolutions based on priority:
- Automatically finds the next available slot
- Respects recurring task rules
- Daily habits compress, weekly habits move to valid days

### Recurring Tasks
Schedule habits and routines:
- Select specific days of the week
- Daily tasks handled differently than weekly
- Instances generated automatically

### Clean Timeline View
- Hourly timeline from 5 AM to midnight
- Side-by-side display for overlapping tasks
- Drag to create new tasks
- Tap to edit or complete

## Screenshots

<!-- Add screenshots here -->
*Coming soon*

## Installation

### Requirements
- iOS 17.0+
- Xcode 15.0+

### Build from Source
```bash
git clone https://github.com/ashishkattamuri/Tempo.git
cd Tempo
open Tempo.xcodeproj
```

Select a simulator and press ⌘R to run.

## Architecture

Built with modern iOS technologies:
- **SwiftUI** - Declarative UI
- **SwiftData** - Persistence
- **MVVM** - Clean separation of concerns

### Key Components
- `ReshuffleEngine` - Core scheduling logic
- `CategoryProcessors` - Priority-specific handling
- `ConflictResolution` - Smart overlap handling

## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Good First Issues
Check out issues labeled [`good first issue`](../../issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22) for beginner-friendly tasks.

## Roadmap

- [ ] Analytics dashboard
- [ ] Apple Calendar sync
- [ ] Widgets
- [ ] Apple Watch app
- [ ] Natural language input

## License

MIT License - see [LICENSE](LICENSE) for details.

---

Built with care by [Ashish Kattamuri](https://github.com/ashishkattamuri)
