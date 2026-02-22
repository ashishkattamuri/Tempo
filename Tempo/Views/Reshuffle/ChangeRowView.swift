import SwiftUI

/// Row displaying a single proposed change from reshuffle.
struct ChangeRowView: View {
    let change: Change
    var isSkipped: Bool = false
    var onToggle: (() -> Void)? = nil

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
                .foregroundColor(isSkipped ? .secondary : iconColor)
                .frame(width: 40)

            // Content
            VStack(alignment: .leading, spacing: 3) {
                Text(change.item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .strikethrough(isSkipped)
                    .foregroundColor(isSkipped ? .secondary : .primary)

                Text(changeDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Category badge
            CategoryBadge(category: change.item.category, size: .small, showLabel: false)

            // Skip/accept toggle (shown only in proposal mode)
            if let toggle = onToggle {
                Button(action: toggle) {
                    Image(systemName: isSkipped ? "minus.circle" : "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(isSkipped ? .secondary : .green)
                }
                .buttonStyle(.plain)
            }
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
            return "Keep as scheduled"

        case .resized(let newDuration):
            let saved = change.item.durationMinutes - newDuration
            return "Trim to \(newDuration) min — saves \(saved) min"

        case .moved(let newTime):
            return "Move to \(timeFormatter.string(from: newTime))"

        case .movedAndResized(let newTime, let newDuration):
            let saved = change.item.durationMinutes - newDuration
            return "Move to \(timeFormatter.string(from: newTime)), trim to \(newDuration) min"

        case .deferred(let newDate):
            return "Defer to \(dateFormatter.string(from: newDate)) at \(timeFormatter.string(from: newDate))"

        case .pooled:
            return "Add to flexible pool"

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
    /// ID of the option the user has already tapped (for highlighting).
    var selectedOptionId: UUID? = nil
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
        let isSelected = option.id == selectedOptionId
        return Button(action: { onSelectOption(option) }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .medium)
                        .foregroundColor(isSelected ? .accentColor : .primary)

                    Text(option.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .accentColor.opacity(0.8) : .secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .accentColor : Color(.systemGray3))
            }
            .padding()
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(Constants.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
            )
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
