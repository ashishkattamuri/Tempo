import SwiftUI

/// Row displaying a single proposed change from reshuffle.
struct ChangeRowView: View {
    let change: Change

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
        HStack(spacing: 12) {
            // Change type icon
            Image(systemName: change.iconName)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 40)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Task title
                Text(change.item.title)
                    .font(.body)
                    .fontWeight(.medium)

                // Change details
                Text(changeDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Reason (compassionate language)
                Text(change.reason)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }

            Spacer()

            // Category badge
            CategoryBadge(category: change.item.category, size: .small, showLabel: false)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(change.item.title), \(change.action.displayName), \(change.reason)")
    }

    // MARK: - Computed Properties

    private var iconColor: Color {
        switch change.action {
        case .protected:
            return .green
        case .resized, .movedAndResized:
            return .orange
        case .moved:
            return .blue
        case .deferred:
            return .purple
        case .pooled:
            return .gray
        case .requiresUserDecision:
            return .red
        }
    }

    private var changeDescription: String {
        switch change.action {
        case .protected:
            return "Stays as scheduled"

        case .resized(let newDuration):
            let saved = change.item.durationMinutes - newDuration
            return "Adjusted to \(newDuration) min (saves \(saved) min)"

        case .moved(let newTime):
            return "Moved to \(timeFormatter.string(from: newTime))"

        case .movedAndResized(let newTime, let newDuration):
            let saved = change.item.durationMinutes - newDuration
            return "Moved to \(timeFormatter.string(from: newTime)), \(newDuration) min (saves \(saved) min)"

        case .deferred(let newDate):
            return "Deferred to \(dateFormatter.string(from: newDate))"

        case .pooled:
            return "Added to flexible pool"

        case .requiresUserDecision:
            return "Needs your decision"
        }
    }
}

/// Section header for grouped changes
struct ChangeSectionHeader: View {
    let title: String
    let count: Int
    let iconName: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundColor(color)

            Text(title)
                .font(.headline)

            Spacer()

            Text("\(count)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(.systemGray5))
                .cornerRadius(8)
        }
    }
}

// MARK: - User Decision View

/// View for changes that require user decision
struct UserDecisionView: View {
    let change: Change
    let onSelectOption: (Change.UserOption) -> Void

    private var options: [Change.UserOption] {
        if case .requiresUserDecision(let opts) = change.action {
            return opts
        }
        return []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView
            reasonView
            optionsView
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(Constants.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
        )
    }

    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            Text(change.item.title)
                .font(.headline)

            Spacer()

            CategoryBadge(category: change.item.category, size: .small, showLabel: false)
        }
    }

    private var reasonView: some View {
        Text(change.reason)
            .font(.subheadline)
            .foregroundColor(.secondary)
    }

    private var optionsView: some View {
        VStack(spacing: 8) {
            ForEach(options) { option in
                optionButton(for: option)
            }
        }
    }

    private func optionButton(for option: Change.UserOption) -> some View {
        Button(action: { onSelectOption(option) }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(option.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(Constants.cornerRadius)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Change Rows") {
    List {
        ChangeRowView(change: Change(
            item: ScheduleItem(
                title: "Morning Run",
                category: .identityHabit,
                startTime: Date().withTime(hour: 7),
                durationMinutes: 45
            ),
            action: .protected,
            reason: "Identity habit protected"
        ))

        ChangeRowView(change: Change(
            item: ScheduleItem(
                title: "Deep Work",
                category: .flexibleTask,
                startTime: Date().withTime(hour: 9),
                durationMinutes: 120
            ),
            action: .resized(newDurationMinutes: 90),
            reason: "Adjusted to fit your schedule"
        ))

        ChangeRowView(change: Change(
            item: ScheduleItem(
                title: "Read Article",
                category: .optionalGoal,
                startTime: Date().withTime(hour: 14),
                durationMinutes: 30
            ),
            action: .deferred(newDate: Date().addingDays(1)),
            reason: "Deferred to tomorrow - today's priorities come first"
        ))
    }
}
