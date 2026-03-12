# Tempo — Smart Day Planner

> Life is unpredictable. Your habits shouldn't pay for it.

![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue.svg)
![SwiftData](https://img.shields.io/badge/Storage-SwiftData-purple.svg)
![Apple Intelligence](https://img.shields.io/badge/Apple_Intelligence-iOS_26-indigo.svg)
![License](https://img.shields.io/badge/License-GPL--3.0-blue.svg)

[![Download on the App Store](https://img.shields.io/badge/App_Store-Tempo%3A_Smart_Day-black?logo=apple)](https://apps.apple.com/us/app/tempo-smart-day/id6759478302)

---

https://github.com/ashishkattamuri/Tempo/raw/main/docs/demo.mp4

---

## What is Tempo?

Every day starts with a plan. Then life happens — an urgent task drops in, an event runs long, something unexpected demands your attention. Most calendar apps leave you to manually shuffle everything around and figure out what gets cut.

Tempo handles the reshuffling for you, based on what actually matters to you.

You tell Tempo which tasks are non-negotiable, which are habits you want to protect, which are flexible, and which are nice-to-haves. When a conflict arises — whether from a new event, an overloaded day, or an ad-hoc task — Tempo proposes a resolution that respects your priorities. Your workouts compress instead of disappearing. Your flexible tasks slide to the next open slot. Your optional goals step aside gracefully. Your non-negotiables never move.

The goal isn't a perfect schedule. It's a schedule that keeps your habits alive, moves you toward your goals, and absorbs whatever the day throws at you.

---

## What's New in Version 2.0

### Focus Block
Automatically block distracting apps during your scheduled tasks — no app needs to stay open. Create named Focus Groups, pick which apps to block using Apple's native app picker, then assign a group to any task. Blocking activates and deactivates automatically in the background via `DeviceActivity` + `ManagedSettings`. A custom branded shield screen shows when a blocked app is opened, with the task name displayed to remind you why you blocked it.

### Fix My Day with Apple Intelligence
On iOS 26+ with Apple Intelligence enabled, the **Fix My Day** flow now proposes personalised rescheduling decisions per task — not just a summary sentence. The on-device model reasons about task context, your sleep schedule, and existing commitments to suggest `move_today`, `compress_today`, or `defer_tomorrow`. The AI plan auto-shows when ready; you can switch back to the rule-based plan at any time. Falls back gracefully to the existing rule-based engine on iOS < 26 or when Apple Intelligence is unavailable.

### Weekly Review
A new AI-powered weekly reflection under Settings → Insights. Shows completion rates by category, a day-by-day bar chart, identity habit streak, and total time invested — plus a compassionate AI-generated summary with one specific insight and one actionable suggestion for next week.

---

## Core Features

### Four Task Categories
| Category | What it is | How conflicts are handled |
|----------|------------|--------------------------|
| **Non-Negotiable** | Fixed commitments — appointments, meetings, deadlines | Never moves. Everything else works around it. |
| **Identity Habit** | Daily practices — exercise, reading, journaling | Compresses to a minimum duration on hard days, never silently dropped. |
| **Flexible Task** | Work that matters but has scheduling room | Rescheduled to the next available slot. |
| **Optional Goal** | Nice-to-haves — learning, side projects | Deferred gracefully when the day is full. |

### Smart Conflict Resolution
- Finds the next genuinely free slot, searching up to 7 days out
- Prioritises by category; same-priority conflicts give you both options
- Never suggests a slot in the past or inside your sleep buffer
- Sleep boundary enforced at both start *and* end of a proposed slot

### Timeline View
- Hourly timeline from 5 AM to midnight
- Side-by-side layout for overlapping tasks
- Tap any time slot to create a task; tap free-time gaps to fill them
- Week strip with activity indicators per day
- Live progress bar for the day

### Recurring Tasks
- Specific days of the week, daily or weekly frequency
- Conflict resolution handles recurring habits differently from one-off tasks

### Sleep Integration
- Set a sleep schedule with a wind-down buffer
- Rescheduling engine never proposes tasks inside the buffer window

### Calendar Import
- Import Apple Calendar events as Non-Negotiable tasks

---

## Getting Started

### Requirements
- iOS 17.0+ (Focus Block requires FamilyControls entitlement approval from Apple)
- Xcode 26.0+ recommended (iOS 26 SDK required for Apple Intelligence features)

### Build & Run
```bash
git clone https://github.com/ashishkattamuri/Tempo.git
cd Tempo
open Tempo.xcodeproj
```

Select any iOS 17+ simulator and press `⌘R`. No external dependencies.

> **Note:** Focus Block (`DeviceActivity` + `ManagedSettings` + `FamilyControls`) requires a physical device with FamilyControls authorization. Apple Intelligence features require iOS 26+ with Apple Intelligence enabled.

---

## Architecture

Built with SwiftUI and SwiftData using MVVM.

```
Tempo/
├── App/                        # Entry point, ContentView
├── Models/                     # ScheduleItem, TaskCategory, FocusGroup, WeeklyStats
├── ViewModels/                 # ScheduleViewModel, ReshuffleViewModel
├── Views/
│   ├── Schedule/               # Main timeline view
│   ├── TaskEdit/               # Create / edit task sheet
│   ├── Reshuffle/              # Fix My Day proposal UI
│   ├── Settings/               # Sleep, Focus Block, Weekly Review
│   ├── Compensation/           # Deferred task tracking
│   └── Components/             # Shared UI components
├── Engine/
│   ├── ReshuffleEngine.swift   # Core conflict detection + slot finding
│   ├── SummaryGenerator.swift
│   └── Processors/             # One processor per category
├── Services/
│   ├── SchedulingAssistant.swift  # Apple Intelligence integration (iOS 26+)
│   ├── FocusBlockManager.swift    # DeviceActivity scheduling + ManagedSettings
│   ├── SleepManager.swift
│   └── NotificationService.swift
├── Data/                       # SwiftData repository layer
└── Utilities/                  # Date extensions, time calculations, constants

TempoFocusExtension/            # DeviceActivityMonitor — applies shields at task start/end
TempoShieldExtension/           # ShieldConfigurationDataSource — custom blocked-app screen
```

---

## Roadmap

Tempo is built in three stages, each making the app meaningfully more useful than the last.

### Stage 1 — Smart Manual Scheduling ✅ *(Version 1.0, shipped)*

A calendar you can trust. Tasks have priorities, conflicts resolve intelligently, habits survive hard days, and your schedule stays honest even when life doesn't cooperate.

The foundation is the `ReshuffleEngine` — a rule-based system that finds free slots, applies category-specific logic, respects sleep boundaries, and proposes changes without ever applying them without your consent. You always decide. The engine handles recurring habits differently from one-off tasks, can compress a habit to its minimum viable duration before deferring it, and searches up to 7 days forward to find a genuinely free slot rather than stacking things arbitrarily.

### Stage 2 — Productivity Intelligence ✅ *(Version 2.0, submitted)*

The app starts working *for* you rather than just responding to you. This means understanding how you actually spend your time, protecting your focus automatically, and using on-device AI to make smarter decisions on your behalf.

**Focus Block** uses `DeviceActivity` + `ManagedSettings` + `FamilyControls` to automatically block distracting apps during scheduled focus sessions — no app needs to stay open, no manual toggling. The block activates and deactivates based on your schedule. A custom branded shield screen with your task name appears when a blocked app is opened.

**Fix My Day with Apple Intelligence** replaces generic rescheduling suggestions with personalised, context-aware decisions. The on-device model reasons about what each task actually is — not just its category — and proposes whether to move it, shorten it, or defer it, while respecting your sleep schedule and every existing commitment. On devices without Apple Intelligence, the proven rule-based engine runs unchanged.

**Weekly Review** gives you a weekly retrospective with completion rates by category, a day-by-day breakdown, identity habit streaks, and an AI-generated narrative — a compassionate summary of how your week went, one specific pattern it noticed, and one concrete suggestion for next week.

The goal: less time managing your schedule, more time executing it.

### Stage 3 — Conversational AI Assistant *(Version 3.0, planned)*

The end state is an assistant you can talk to. Not just a chatbot layered on top of a calendar, but an agent that understands your priorities, knows your history, and can negotiate your schedule on your behalf.

> *"I have a deadline Friday — help me protect time for deep work this week."*
> *"Move everything non-essential out of tomorrow morning."*
> *"What did I spend the most time on last week?"*

The scheduling logic Tempo has built — priority rules, conflict resolution, habit preservation, sleep awareness — becomes the reasoning layer the AI operates on. The assistant doesn't replace your judgment, it amplifies it.

Planned for this stage: smart task creation from natural language, auto-categorisation as you type, an evening planning assistant that briefs you on tomorrow, and proactive warnings when your day is overloaded before you notice it yourself.

---

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for setup and guidelines.

Good places to start — issues labeled [`good first issue`](../../issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22):
- Localization (Spanish, French, German)
- Widget for today's schedule
- Swipe gestures on task cards
- Empty state illustrations for days with no tasks
- Unit tests for `ReshuffleEngine` edge cases
- Natural language task creation (e.g. "Meeting at 3pm for 1 hour")

---

## License

GPL-3.0 — see [LICENSE](LICENSE).

---

Built by [Ashish Kattamuri](https://github.com/ashishkattamuri)
