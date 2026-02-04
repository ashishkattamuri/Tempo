import Foundation
import SwiftData
import Observation

/// ViewModel for the main schedule view.
/// Manages schedule items and provides computed properties for the UI.
@MainActor
@Observable
final class ScheduleViewModel {
    // MARK: - Dependencies

    private let repository: ScheduleRepository
    private let reshuffleEngine = ReshuffleEngine()

    // MARK: - State

    var selectedDate: Date = Date()
    var items: [ScheduleItem] = []
    var isLoading = false
    var error: Error?

    // MARK: - Computed Properties

    var sortedItems: [ScheduleItem] {
        items.sorted { $0.startTime < $1.startTime }
    }

    var incompleteItems: [ScheduleItem] {
        items.filter { !$0.isCompleted }
    }

    var completedItems: [ScheduleItem] {
        items.filter { $0.isCompleted }
    }

    var completionPercentage: Double {
        guard !items.isEmpty else { return 0 }
        return Double(completedItems.count) / Double(items.count)
    }

    var totalScheduledMinutes: Int {
        items.reduce(0) { $0 + $1.durationMinutes }
    }

    var completedMinutes: Int {
        completedItems.reduce(0) { $0 + $1.durationMinutes }
    }

    var hasScheduleIssues: Bool {
        reshuffleEngine.hasIssues(items: items, for: selectedDate)
    }

    var statusMessage: String {
        reshuffleEngine.statusMessage(items: items, for: selectedDate)
    }

    // MARK: - Items by Category

    var nonNegotiables: [ScheduleItem] {
        items.filter { $0.category == .nonNegotiable }
    }

    var identityHabits: [ScheduleItem] {
        items.filter { $0.category == .identityHabit }
    }

    var flexibleTasks: [ScheduleItem] {
        items.filter { $0.category == .flexibleTask }
    }

    var optionalGoals: [ScheduleItem] {
        items.filter { $0.category == .optionalGoal }
    }

    // MARK: - Evening Items

    var eveningItems: [ScheduleItem] {
        items.filter { $0.isEveningTask }
    }

    var eveningFreeMinutes: Int {
        TimeCalculations.eveningFreeMinutes(on: selectedDate, items: items)
    }

    // MARK: - Initialization

    init(repository: ScheduleRepository) {
        self.repository = repository
    }

    // MARK: - Data Operations

    func loadItems() async {
        isLoading = true
        error = nil

        do {
            items = try await repository.fetchItems(for: selectedDate)
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func loadItems(for date: Date) async {
        selectedDate = date
        await loadItems()
    }

    func createItem(_ item: ScheduleItem) async throws {
        try await repository.create(item)
        await loadItems()
    }

    func updateItem(_ item: ScheduleItem) async throws {
        try await repository.update(item)
        await loadItems()
    }

    func deleteItem(_ item: ScheduleItem) async throws {
        try await repository.delete(item)
        await loadItems()
    }

    func toggleCompletion(_ item: ScheduleItem) async throws {
        if item.isCompleted {
            try await repository.markIncomplete(item)
        } else {
            try await repository.markCompleted(item)
        }
        await loadItems()
    }

    // MARK: - Date Navigation

    func goToToday() {
        selectedDate = Date()
        Task {
            await loadItems()
        }
    }

    func goToPreviousDay() {
        selectedDate = selectedDate.addingDays(-1)
        Task {
            await loadItems()
        }
    }

    func goToNextDay() {
        selectedDate = selectedDate.addingDays(1)
        Task {
            await loadItems()
        }
    }

    // MARK: - Quick Stats

    struct DayStats {
        let totalTasks: Int
        let completedTasks: Int
        let totalMinutes: Int
        let completedMinutes: Int
        let hasIssues: Bool

        var completionRate: Double {
            guard totalTasks > 0 else { return 0 }
            return Double(completedTasks) / Double(totalTasks)
        }
    }

    var dayStats: DayStats {
        DayStats(
            totalTasks: items.count,
            completedTasks: completedItems.count,
            totalMinutes: totalScheduledMinutes,
            completedMinutes: completedMinutes,
            hasIssues: hasScheduleIssues
        )
    }
}
