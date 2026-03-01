import ActivityKit
import WidgetKit
import SwiftUI

struct TempoLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TaskLiveActivityAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
                .padding()
                .background(.ultraThinMaterial)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.taskTitle, systemImage: categoryIcon(context.state.categoryRawValue))
                        .font(.caption)
                        .foregroundColor(categoryColor(context.state.categoryRawValue))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(
                        timerInterval: Date()...context.state.endTime,
                        countsDown: true
                    )
                    .tint(categoryColor(context.state.categoryRawValue))
                }
            } compactLeading: {
                Image(systemName: categoryIcon(context.state.categoryRawValue))
                    .foregroundColor(categoryColor(context.state.categoryRawValue))
            } compactTrailing: {
                Text(context.state.endTime, style: .timer)
                    .font(.caption2)
                    .monospacedDigit()
                    .frame(width: 40)
            } minimal: {
                Image(systemName: categoryIcon(context.state.categoryRawValue))
                    .foregroundColor(categoryColor(context.state.categoryRawValue))
            }
            .widgetURL(URL(string: "tempo://schedule"))
        }
    }
}

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<TaskLiveActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: categoryIcon(context.state.categoryRawValue))
                .foregroundColor(categoryColor(context.state.categoryRawValue))
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.taskTitle)
                    .font(.headline)
                    .lineLimit(1)

                ProgressView(
                    timerInterval: Date()...context.state.endTime,
                    countsDown: true,
                    label: { EmptyView() },
                    currentValueLabel: {
                        Text(context.state.endTime, style: .timer)
                            .font(.caption)
                            .monospacedDigit()
                    }
                )
                .tint(categoryColor(context.state.categoryRawValue))
            }
        }
    }
}

private func categoryIcon(_ rawValue: String) -> String {
    switch rawValue {
    case "non_negotiable": return "lock.fill"
    case "identity_habit": return "heart.fill"
    case "flexible_task": return "arrow.left.arrow.right"
    case "optional_goal": return "star"
    default: return "clock"
    }
}

private func categoryColor(_ rawValue: String) -> Color {
    switch rawValue {
    case "non_negotiable": return .red
    case "identity_habit": return .purple
    case "flexible_task": return .blue
    case "optional_goal": return .green
    default: return .accentColor
    }
}