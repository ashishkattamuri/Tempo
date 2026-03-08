import Foundation

/// Aggregated statistics for a 7-day period, computed from ScheduleItems.
struct WeeklyStats {
    let weekStart: Date
    let weekEnd: Date
    private let items: [ScheduleItem]

    init(items: [ScheduleItem], weekStart: Date, weekEnd: Date) {
        self.items = items
        self.weekStart = weekStart
        self.weekEnd = weekEnd
    }

    // MARK: - Totals

    var totalScheduled: Int { items.count }
    var totalCompleted: Int { items.filter(\.isCompleted).count }
    var completionRate: Double {
        totalScheduled > 0 ? Double(totalCompleted) / Double(totalScheduled) : 0
    }

    var totalMinutesCompleted: Int {
        items.filter(\.isCompleted).reduce(0) { $0 + $1.durationMinutes }
    }
    var totalHoursCompleted: Int { totalMinutesCompleted / 60 }

    // MARK: - By Category

    struct CategoryRow {
        let category: TaskCategory
        let scheduled: Int
        let completed: Int
        var rate: Double { scheduled > 0 ? Double(completed) / Double(scheduled) : 0 }
    }

    var byCategory: [CategoryRow] {
        TaskCategory.allCases.compactMap { cat in
            let catItems = items.filter { $0.category == cat }
            guard !catItems.isEmpty else { return nil }
            return CategoryRow(
                category: cat,
                scheduled: catItems.count,
                completed: catItems.filter(\.isCompleted).count
            )
        }
    }

    // MARK: - Day Breakdown

    struct DayRow {
        let date: Date
        let scheduled: Int
        let completed: Int
    }

    var byDay: [DayRow] {
        let cal = Calendar.current
        var current = weekStart
        var rows: [DayRow] = []
        while current <= weekEnd {
            let dayItems = items.filter { $0.scheduledDate.isSameDay(as: current) }
            if !dayItems.isEmpty {
                rows.append(DayRow(
                    date: current,
                    scheduled: dayItems.count,
                    completed: dayItems.filter(\.isCompleted).count
                ))
            }
            current = cal.date(byAdding: .day, value: 1, to: current) ?? current
        }
        return rows
    }

    var bestDay: DayRow? {
        byDay.max(by: { $0.completed < $1.completed })
    }

    var hardestDay: DayRow? {
        byDay
            .filter { $0.scheduled > 0 && $0.completed < $0.scheduled }
            .min(by: { Double($0.completed) / Double($0.scheduled) < Double($1.completed) / Double($1.scheduled) })
    }

    // MARK: - Identity Habit Streak

    /// Number of consecutive days (ending today or yesterday) where all identity habits were completed.
    var identityHabitStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var day = Date()
        for _ in 0..<7 {
            let dayHabits = items.filter {
                $0.category == .identityHabit && $0.scheduledDate.isSameDay(as: day)
            }
            guard !dayHabits.isEmpty else { break }
            let allDone = dayHabits.allSatisfy(\.isCompleted)
            if allDone { streak += 1 } else { break }
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return streak
    }

    // MARK: - Factory

    static func forCurrentWeek(items: [ScheduleItem]) -> WeeklyStats {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)  // 1=Sun
        let daysSinceMonday = (weekday + 5) % 7             // Mon=0
        let weekStart = cal.date(byAdding: .day, value: -daysSinceMonday, to: today) ?? today
        let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) ?? today

        let weekItems = items.filter {
            $0.scheduledDate >= weekStart && $0.scheduledDate <= weekEnd
        }
        return WeeklyStats(items: weekItems, weekStart: weekStart, weekEnd: weekEnd)
    }

    static func forLastWeek(items: [ScheduleItem]) -> WeeklyStats {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysSinceMonday = (weekday + 5) % 7
        let thisWeekStart = cal.date(byAdding: .day, value: -daysSinceMonday, to: today) ?? today
        let weekStart = cal.date(byAdding: .day, value: -7, to: thisWeekStart) ?? today
        let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) ?? today

        let weekItems = items.filter {
            $0.scheduledDate >= weekStart && $0.scheduledDate <= weekEnd
        }
        return WeeklyStats(items: weekItems, weekStart: weekStart, weekEnd: weekEnd)
    }
}
