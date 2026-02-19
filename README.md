# Tempo — Smart Schedule Assistant

> Life is unpredictable. Your habits shouldn't pay for it.

![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue.svg)
![SwiftData](https://img.shields.io/badge/Storage-SwiftData-purple.svg)
![License](https://img.shields.io/badge/License-GPL--3.0-blue.svg)

---

<!-- Add a demo GIF here -->
<!-- ![Tempo Demo](assets/demo.gif) -->

## What is Tempo?

Every day starts with a plan. Then life happens — an urgent task drops in, an event runs long, something unexpected demands your attention. Most calendar apps leave you to manually shuffle everything around and figure out what gets cut.

Tempo handles the reshuffling for you, based on what actually matters to you.

You tell Tempo which tasks are non-negotiable, which are habits you want to protect, which are flexible, and which are nice-to-haves. When a conflict arises — whether from a new event, an overloaded day, or an ad-hoc task — Tempo proposes a resolution that respects your priorities. Your workouts compress instead of disappearing. Your flexible tasks slide to the next open slot. Your optional goals step aside gracefully. Your non-negotiables never move.

The goal isn't a perfect schedule. It's a schedule that keeps your habits alive, moves you toward your goals, and absorbs whatever the day throws at you.

---

## How It Works

### Four Task Categories
The foundation of Tempo is a simple priority model. Every task belongs to one of four categories, each with its own conflict behavior:

| Category | What it is | How conflicts are handled |
|----------|------------|--------------------------|
| **Non-Negotiable** | Fixed commitments — appointments, meetings, deadlines | Never moves. Everything else works around it. |
| **Identity Habit** | Daily practices you're building — exercise, reading, journaling | Can compress to a minimum duration on hard days, but never silently dropped. |
| **Flexible Task** | Work that matters but has some scheduling room | Automatically rescheduled to the next available slot. |
| **Optional Goal** | Nice-to-haves — learning, side projects, low-priority tasks | Deferred gracefully when the day is full. |

### Smart Conflict Resolution
When tasks overlap, Tempo doesn't just flag the conflict — it suggests how to resolve it:

- Finds the next genuinely free slot, searching up to 7 days out
- Prioritizes by category: a non-negotiable always wins over a flexible task
- For same-priority conflicts, gives you both options and lets you decide
- Daily habits offer compress-or-keep-both options on packed days
- Weekly recurring tasks move to a day that doesn't already have that habit scheduled
- Never suggests a slot in the past

### Timeline View
- Hourly timeline from 5 AM to midnight
- Side-by-side layout when tasks overlap
- Compact mode for short tasks (≤ 30 minutes)
- Tap any time slot to create a task right there
- Free-time gap indicators ("2h available") — tap to fill them
- Week strip at the top with activity indicators per day
- Live progress bar showing how much of the day is done

### Recurring Tasks
- Select specific days of the week
- Daily and weekly frequencies handled differently in conflict resolution
- Instances generated automatically

---

## Screenshots

<!-- Replace with actual screenshots -->
*Screenshots coming soon.*

---

## Getting Started

### Requirements
- iOS 17.0+
- Xcode 15.0+

### Build & Run
```bash
git clone https://github.com/ashishkattamuri/Tempo.git
cd Tempo
open Tempo.xcodeproj
```

Select any iOS 17 simulator and press `⌘R`. No dependencies, no package manager setup.

---

## Architecture

Built with SwiftUI and SwiftData using MVVM.

```
Tempo/
├── App/                    # Entry point, ContentView
├── Models/                 # ScheduleItem, TaskCategory, RecurrenceFrequency
├── ViewModels/             # ScheduleViewModel, ReshuffleViewModel
├── Views/
│   ├── Schedule/           # Main timeline view
│   ├── TaskEdit/           # Create / edit task sheet
│   ├── Reshuffle/          # Conflict resolution proposal UI
│   ├── Compensation/       # Deferred task tracking
│   └── Settings/           # App settings
├── Engine/
│   ├── ReshuffleEngine.swift       # Core conflict detection + slot finding
│   ├── SummaryGenerator.swift
│   └── Processors/                 # One processor per category
│       ├── NonNegotiableProcessor.swift
│       ├── IdentityHabitProcessor.swift
│       ├── FlexibleTaskProcessor.swift
│       └── OptionalGoalProcessor.swift
├── Data/                   # SwiftData repository layer
└── Utilities/              # Date extensions, time calculations, constants
```

The `ReshuffleEngine` is the core of the app. It finds free slots, applies category-specific rules, handles recurring task logic, and proposes changes without applying them — the user always decides.

---

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for setup and guidelines.

Good places to start — issues labeled [`good first issue`](../../issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22):
- Haptic feedback on task completion
- Dark mode polish
- Empty state for days with no tasks
- Swipe gestures on task cards
- Unit tests for `ReshuffleEngine`
- Localization (Spanish, French, German)

---

## Roadmap

- [ ] Analytics — time spent by category, weekly trends
- [ ] Task inbox — backlog of unscheduled tasks with auto-suggest
- [ ] Apple Calendar sync
- [ ] iOS widget
- [ ] Natural language input ("Move my 3pm to tomorrow")

---

## License

GPL-3.0 — see [LICENSE](LICENSE).

---

Built by [Ashish Kattamuri](https://github.com/ashishkattamuri)
