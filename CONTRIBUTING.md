# Contributing to Tempo

Thanks for your interest in contributing to Tempo! This document provides guidelines for contributing.

## Getting Started

1. **Fork the repository** and clone it locally
2. **Open in Xcode** - Open `Tempo.xcodeproj`
3. **Run the app** - Select an iOS Simulator and hit Run (⌘R)

## Requirements

- Xcode 15.0+
- iOS 17.0+ (deployment target)
- Swift 5.9+

## How to Contribute

### Reporting Bugs

- Check if the issue already exists
- Open a new issue with:
  - Clear title
  - Steps to reproduce
  - Expected vs actual behavior
  - iOS version and device/simulator

### Suggesting Features

- Open an issue with the `enhancement` label
- Describe the use case and proposed solution

### Submitting Code

1. **Find an issue** - Look for `good first issue` or `help wanted` labels
2. **Comment** - Let others know you're working on it
3. **Fork & Branch** - Create a branch from `main`
4. **Code** - Follow the existing code style
5. **Test** - Make sure the app builds and runs
6. **PR** - Submit a pull request with:
   - Reference to the issue
   - Description of changes
   - Screenshots/GIFs if UI changed

## Code Style

- Follow existing patterns in the codebase
- Use SwiftUI for all new views
- Use SwiftData for persistence
- Keep files focused and reasonably sized
- Use meaningful variable and function names

## Project Structure

```
Tempo/
├── App/           # App entry point, ContentView
├── Models/        # Data models (ScheduleItem, TaskCategory, etc.)
├── Views/         # SwiftUI views organized by feature
├── ViewModels/    # View models for complex views
├── Engine/        # Reshuffle logic and processors
├── Data/          # Repository and persistence
├── Services/      # External services (Sleep, Notifications)
└── Utilities/     # Extensions and helpers
```

## Questions?

Open an issue with the `question` label or start a discussion.

Thanks for helping make Tempo better!
