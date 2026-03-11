import SwiftUI

struct ScheduleExportView: View {
    let date: Date
    let items: [ScheduleItem]

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    private var completedCount: Int {
        items.filter { $0.isCompleted }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Tempo")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(completedCount)/\(items.count) done")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(dateString)
                    .font(.title2)
                    .fontWeight(.bold)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.systemGray5))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.green)
                            .frame(
                                width: items.isEmpty ? 0 : geo.size.width * CGFloat(completedCount) / CGFloat(items.count),
                                height: 6
                            )
                    }
                }
                .frame(height: 6)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(Color(.systemBackground))

            Divider()

            // Task list
            if items.isEmpty {
                Text("No tasks scheduled")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(40)
            } else {
                VStack(spacing: 0) {
                    ForEach(items.sorted { $0.startTime < $1.startTime }) { item in
                        exportTaskRow(item)
                        if item.id != items.sorted(by: { $0.startTime < $1.startTime }).last?.id {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
            }

            // Footer
            Divider()
            HStack {
                Spacer()
                Text("Made with Tempo")
                    .font(.caption2)
                    .foregroundStyle(Color(.systemGray3))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func exportTaskRow(_ item: ScheduleItem) -> some View {
        HStack(spacing: 12) {
            // Category color dot + icon
            ZStack {
                Circle()
                    .fill(item.category.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: item.category.iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(item.category.color)
            }

            // Task info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    .strikethrough(item.isCompleted)

                Text(formatTimeRange(item))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Duration badge
            Text("\(item.durationMinutes) min")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .clipShape(Capsule())

            // Completion indicator
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isCompleted ? Color.green : Color(.systemGray4))
                .font(.system(size: 18))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    private func formatTimeRange(_ item: ScheduleItem) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: item.startTime)) – \(formatter.string(from: item.endTime))"
    }
}