import Foundation
import SwiftUI

/// Tracks compensation debt for deferred or cancelled Optional Goals.
/// Identity Habits that get compressed do NOT create debt - showing up in any form counts.
@MainActor
final class CompensationTracker: ObservableObject {
    @Published var pendingCompensations: [CompensationRecord] = []

    private let userDefaultsKey = "CompensationTracker.records"

    init() {
        loadRecords()
    }

    // MARK: - Persistence

    private func loadRecords() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let records = try? JSONDecoder().decode([CompensationRecord].self, from: data) {
            pendingCompensations = records.filter { !$0.isFullyCompensated }
        }
    }

    private func saveRecords() {
        if let data = try? JSONEncoder().encode(pendingCompensations) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    // MARK: - Record Debt

    /// Records a compensation debt for a deferred or cancelled task.
    /// Only call this for Optional Goals - not for Identity Habits.
    func recordDebt(item: ScheduleItem, lostMinutes: Int, reason: CompensationRecord.CompensationReason) {
        // Only Optional Goals track compensation debt
        guard item.category == .optionalGoal else { return }
        guard lostMinutes > 0 else { return }

        let record = CompensationRecord(
            taskId: item.id,
            taskTitle: item.title,
            category: item.category,
            lostMinutes: lostMinutes,
            originalDate: item.scheduledDate,
            reason: reason
        )

        pendingCompensations.append(record)
        saveRecords()
    }

    /// Records debt for a flexible task (optional behavior based on user preference)
    func recordFlexibleDebt(item: ScheduleItem, lostMinutes: Int, reason: CompensationRecord.CompensationReason) {
        guard item.category == .flexibleTask else { return }
        guard lostMinutes > 0 else { return }

        let record = CompensationRecord(
            taskId: item.id,
            taskTitle: item.title,
            category: item.category,
            lostMinutes: lostMinutes,
            originalDate: item.scheduledDate,
            reason: reason
        )

        pendingCompensations.append(record)
        saveRecords()
    }

    // MARK: - Find Compensation Slots

    /// Finds available slots for compensation, prioritizing weekends
    func findCompensationSlots(for record: CompensationRecord, in items: [ScheduleItem]) -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var slots: [Date] = []

        // Search the next 2 weeks for slots
        for dayOffset in 0..<14 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }

            // Get items for this day
            let dayItems = items.filter { $0.scheduledDate.isSameDay(as: date) }

            // Find free slots
            let freeSlots = TimeCalculations.findAvailableSlots(
                on: date,
                existingItems: dayItems,
                minimumDuration: record.remainingMinutes
            )

            // Prioritize weekend slots
            let isWeekend = TimeCalculations.isWeekend(date)

            for slot in freeSlots {
                if isWeekend {
                    // Weekend slots go to the front
                    slots.insert(slot.start, at: 0)
                } else {
                    slots.append(slot.start)
                }
            }
        }

        return Array(slots.prefix(5)) // Return top 5 suggestions
    }

    /// Gets suggested weekend slots for a specific duration
    func getWeekendSlots(startingFrom date: Date, durationNeeded: Int, existingItems: [ScheduleItem]) -> [Date] {
        let calendar = Calendar.current
        var slots: [Date] = []

        // Find the next 2 weekends
        var checkDate = date
        var weekendsFound = 0

        while weekendsFound < 2 {
            if TimeCalculations.isWeekend(checkDate) {
                let dayItems = existingItems.filter { $0.scheduledDate.isSameDay(as: checkDate) }
                let freeSlots = TimeCalculations.findAvailableSlots(
                    on: checkDate,
                    existingItems: dayItems,
                    minimumDuration: durationNeeded
                )

                slots.append(contentsOf: freeSlots.map { $0.start })

                // Check if it's Sunday, which ends the weekend
                let weekday = calendar.component(.weekday, from: checkDate)
                if weekday == 1 { // Sunday
                    weekendsFound += 1
                }
            }

            checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate) ?? checkDate
        }

        return Array(slots.prefix(5))
    }

    // MARK: - Schedule Compensation

    /// Creates a compensation task for the given record
    func scheduleCompensation(for record: CompensationRecord, at date: Date) -> ScheduleItem {
        let compensationTask = ScheduleItem(
            title: "Make up: \(record.taskTitle)",
            category: record.category,
            startTime: date,
            durationMinutes: record.remainingMinutes,
            notes: "Compensation for \(record.taskTitle) on \(formattedDate(record.originalDate))",
            scheduledDate: Calendar.current.startOfDay(for: date),
            isCompensationTask: true,
            originalTaskId: record.taskId
        )

        return compensationTask
    }

    /// Marks a record as compensated
    func markCompensated(_ record: CompensationRecord, minutes: Int, date: Date) {
        if let index = pendingCompensations.firstIndex(where: { $0.id == record.id }) {
            pendingCompensations[index].recordCompensation(minutes: minutes, date: date)

            // Remove if fully compensated
            if pendingCompensations[index].isFullyCompensated {
                pendingCompensations.remove(at: index)
            }

            saveRecords()
        }
    }

    /// Removes a compensation record (e.g., if user decides not to make it up)
    func dismissCompensation(_ record: CompensationRecord) {
        pendingCompensations.removeAll { $0.id == record.id }
        saveRecords()
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    /// Total minutes of pending compensation
    var totalPendingMinutes: Int {
        pendingCompensations.reduce(0) { $0 + $1.remainingMinutes }
    }

    /// Whether there are any pending compensations
    var hasPendingCompensations: Bool {
        !pendingCompensations.isEmpty
    }

    /// Formatted total pending time
    var formattedPendingTime: String {
        let minutes = totalPendingMinutes
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins > 0 {
                return "\(hours)h \(mins)m"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(minutes)m"
        }
    }
}
