# Tempo — Smart Schedule Assistant

> A calendar app that thinks like a personal assistant. Add tasks, resolve conflicts by priority, and let your daily habits hold their ground.

![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue.svg)
![SwiftData](https://img.shields.io/badge/Storage-SwiftData-purple.svg)
![License](https://img.shields.io/badge/License-GPL--3.0-blue.svg)

---

<!-- Add a demo GIF here -->
<!-- ![Tempo Demo](assets/demo.gif) -->

## Why Tempo?

Most calendar apps treat every task the same. Tempo doesn't.

When you schedule a meeting over your morning run, Tempo knows your run is an *identity habit* — it can compress to 10 minutes, but it doesn't disappear. When a flexible task conflicts with a non-negotiable, Tempo moves the flexible one and tells you why. When your day gets too full, it surfaces the right thing to defer.

Your priorities are built into the schedule, not just your head.

---

## Features

### Four Task Categories
Each category has its own conflict rules:

| Category | Behavior |
|----------|----------|
| **Non-Negotiable** | Never moves. Everything else works around it. |
| **Identity Habit** | Can compress to a minimum on hard days, but never silently dropped. |
| **Flexible Task** | Auto-rescheduled to the next open slot. |
| **Optional Goal** | Deferred when the day is full — no guilt. |

### Smart Conflict Resolution
When tasks overlap, Tempo suggests a resolution based on priority — not just chronology:
- Finds the next truly free slot, up to 7 days out
- Daily habits offer compress-or-keep-both options
- Weekly habits move to a valid day that doesn't already have the same habit
- Never suggests a slot in the past

### Timeline View
- Hourly timeline from 5 AM to midnight
- Side-by-side layout for overlapping tasks
- Compact mode for tasks ≤ 30 minutes
- Tap any hour slot to create a task at that time
- Free-time gap indicators ("2h available")
- Live progress bar showing tasks done vs. remaining

### Recurring Tasks
- Choose specific days of the week
- Daily and weekly frequencies handled differently in conflict logic
- Instances generated automatically

### Evening Protection
Tasks marked as evening tasks require explicit consent before being moved into your wind-down time.

---

## Screenshots

<!-- Replace with actual screenshots once available -->
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
│   ├── Reshuffle/          # Conflict resolution UI
│   ├── Compensation/       # Deferred task tracking
│   └── Settings/           # Sleep schedule settings
├── Engine/
│   ├── ReshuffleEngine.swift            # Core conflict + slot logic
│   ├── EveningProtectionAnalyzer.swift
│   ├── SummaryGenerator.swift
│   └── Processors/                      # One processor per category
│       ├── NonNegotiableProcessor.swift
│       ├── IdentityHabitProcessor.swift
│       ├── FlexibleTaskProcessor.swift
│       └── OptionalGoalProcessor.swift
├── Data/                   # SwiftData repository layer
└── Utilities/              # Date extensions, time calculations, constants
```

The `ReshuffleEngine` is the core of the app. It finds free slots, applies category-specific rules, handles recurring habit logic, and proposes changes without applying them — the user always has the final say.

---

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Good places to start — issues labeled [`good first issue`](../../issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22) on GitHub:
- Haptic feedback on task completion
- Dark mode polish
- iOS widget for today's schedule
- Import events from Apple Calendar
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
