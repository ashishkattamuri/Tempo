import SwiftUI
import SwiftData

struct WeeklyRetrospectiveView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allItems: [ScheduleItem]

    @State private var stats: WeeklyStats?
    @State private var retrospective: (summary: String, insight: String, suggestion: String, encouragement: String)?
    @State private var isGenerating = false
    @State private var showingLastWeek = false

    private var activeStats: WeeklyStats {
        showingLastWeek
            ? WeeklyStats.forLastWeek(items: Array(allItems))
            : WeeklyStats.forCurrentWeek(items: Array(allItems))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    weekPicker
                    overviewCard
                    categoryBreakdown
                    dayBreakdown
                    aiSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Weekly Review")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: showingLastWeek) {
                await generateAI()
            }
        }
    }

    // MARK: - Week Picker

    private var weekPicker: some View {
        let dateFmt: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            return f
        }()
        let s = activeStats
        return Picker("Week", selection: $showingLastWeek) {
            Text("This Week").tag(false)
            Text("Last Week").tag(true)
        }
        .pickerStyle(.segmented)
        .overlay(alignment: .bottom) {
            Text("\(dateFmt.string(from: s.weekStart)) – \(dateFmt.string(from: s.weekEnd))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .offset(y: 20)
        }
        .padding(.bottom, 24)
    }

    // MARK: - Overview Card

    private var overviewCard: some View {
        let s = activeStats
        let pct = Int(s.completionRate * 100)
        return VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(pct)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(color(for: s.completionRate))
                Text("%")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(s.totalCompleted) of \(s.totalScheduled)")
                        .font(.headline)
                    Text("tasks completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                statPill(
                    icon: "clock.fill",
                    value: "\(s.totalHoursCompleted)h \(s.totalMinutesCompleted % 60)m",
                    label: "time invested",
                    color: .blue
                )
                Spacer()
                if s.identityHabitStreak > 0 {
                    statPill(
                        icon: "flame.fill",
                        value: "\(s.identityHabitStreak)d",
                        label: "habit streak",
                        color: .orange
                    )
                }
                if let best = s.bestDay {
                    let dayFmt = DateFormatter()
                    let _ = { dayFmt.dateFormat = "EEE" }()
                    statPill(
                        icon: "star.fill",
                        value: dayFmt.string(from: best.date),
                        label: "best day",
                        color: .yellow
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statPill(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.subheadline.weight(.semibold))
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Category Breakdown

    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Category")
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(activeStats.byCategory, id: \.category) { row in
                    categoryRow(row)
                }
            }
        }
    }

    private func categoryRow(_ row: WeeklyStats.CategoryRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(row.category.displayName, systemImage: row.category.iconName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(row.category.color)
                Spacer()
                Text("\(row.completed)/\(row.scheduled)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(row.category.color.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(row.category.color)
                        .frame(width: geo.size.width * row.rate, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Day Breakdown

    private var dayBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Day by Day")
                .font(.headline)
                .padding(.horizontal, 4)

            HStack(alignment: .bottom, spacing: 6) {
                let days = activeStats.byDay
                let maxScheduled = days.map(\.scheduled).max() ?? 1
                ForEach(days, id: \.date) { day in
                    dayBar(day: day, maxScheduled: maxScheduled)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func dayBar(day: WeeklyStats.DayRow, maxScheduled: Int) -> some View {
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "EEE"
        let barHeight: CGFloat = 80
        let scheduledH = barHeight * CGFloat(day.scheduled) / CGFloat(maxScheduled)
        let completedH = barHeight * CGFloat(day.completed) / CGFloat(maxScheduled)

        return VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: scheduledH)
                RoundedRectangle(cornerRadius: 4)
                    .fill(color(for: day.scheduled > 0 ? Double(day.completed) / Double(day.scheduled) : 0))
                    .frame(height: completedH)
            }
            .frame(maxWidth: .infinity)
            Text(dayFmt.string(from: day.date))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - AI Section

    @ViewBuilder
    private var aiSection: some View {
        if isGenerating {
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 32))
                    .foregroundStyle(.indigo)
                    .symbolEffect(.pulse)
                Text("Apple Intelligence is reflecting on your week...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(Color.indigo.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        } else if let r = retrospective {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.indigo)
                    Text("Apple Intelligence")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.indigo)
                }

                narrativeBlock(icon: "text.bubble.fill", color: .indigo, text: r.summary)
                narrativeBlock(icon: "lightbulb.fill", color: .orange, text: r.insight)
                narrativeBlock(icon: "arrow.right.circle.fill", color: .green, text: r.suggestion)

                Text(r.encouragement)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.indigo)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
            .padding()
            .background(Color.indigo.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func narrativeBlock(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Helpers

    private func color(for rate: Double) -> Color {
        switch rate {
        case 0.8...: return .green
        case 0.5...: return .orange
        default: return .red
        }
    }

    private func generateAI() async {
        guard #available(iOS 26, *) else { return }
        retrospective = nil
        isGenerating = true
        let s = activeStats
        if let result = await SchedulingAssistant.shared.generateRetrospective(stats: s) {
            retrospective = (result.summary, result.insight, result.suggestion, result.encouragement)
        }
        isGenerating = false
    }
}

#Preview {
    WeeklyRetrospectiveView()
        .modelContainer(for: ScheduleItem.self, inMemory: true)
}
