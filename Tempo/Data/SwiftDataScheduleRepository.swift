import Foundation
import SwiftData

/// SwiftData implementation of ScheduleRepository.
/// Handles all persistence operations using SwiftData's ModelContext.
@MainActor
final class SwiftDataScheduleRepository: ScheduleRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Fetch Operations

    func fetchItems(for date: Date) async throws -> [ScheduleItem] {
        let startOfDay = date.startOfDay
        let endOfDay = date.endOfDay

        let predicate = #Predicate<ScheduleItem> { item in
            item.scheduledDate >= startOfDay && item.scheduledDate <= endOfDay
        }

        let descriptor = FetchDescriptor<ScheduleItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw RepositoryError.fetchFailed(error)
        }
    }

    func fetchItems(from startDate: Date, to endDate: Date) async throws -> [ScheduleItem] {
        let start = startDate.startOfDay
        let end = endDate.endOfDay

        let predicate = #Predicate<ScheduleItem> { item in
            item.scheduledDate >= start && item.scheduledDate <= end
        }

        let descriptor = FetchDescriptor<ScheduleItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.scheduledDate), SortDescriptor(\.startTime)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw RepositoryError.fetchFailed(error)
        }
    }

    func fetchItem(id: UUID) async throws -> ScheduleItem? {
        let predicate = #Predicate<ScheduleItem> { item in
            item.id == id
        }

        let descriptor = FetchDescriptor<ScheduleItem>(predicate: predicate)

        do {
            let results = try modelContext.fetch(descriptor)
            return results.first
        } catch {
            throw RepositoryError.fetchFailed(error)
        }
    }

    func fetchIncompleteItems(for date: Date) async throws -> [ScheduleItem] {
        let startOfDay = date.startOfDay
        let endOfDay = date.endOfDay

        let predicate = #Predicate<ScheduleItem> { item in
            item.scheduledDate >= startOfDay &&
            item.scheduledDate <= endOfDay &&
            item.isCompleted == false
        }

        let descriptor = FetchDescriptor<ScheduleItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw RepositoryError.fetchFailed(error)
        }
    }

    func fetchEveningItems(for date: Date) async throws -> [ScheduleItem] {
        let startOfDay = date.startOfDay
        let endOfDay = date.endOfDay

        let predicate = #Predicate<ScheduleItem> { item in
            item.scheduledDate >= startOfDay &&
            item.scheduledDate <= endOfDay &&
            item.isEveningTask == true
        }

        let descriptor = FetchDescriptor<ScheduleItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw RepositoryError.fetchFailed(error)
        }
    }

    // MARK: - Create, Update, Delete

    func create(_ item: ScheduleItem) async throws {
        modelContext.insert(item)
        try save()
    }

    func update(_ item: ScheduleItem) async throws {
        item.touch()
        try save()
    }

    func delete(_ item: ScheduleItem) async throws {
        modelContext.delete(item)
        try save()
    }

    func delete(id: UUID) async throws {
        guard let item = try await fetchItem(id: id) else {
            throw RepositoryError.itemNotFound(id)
        }
        try await delete(item)
    }

    // MARK: - Batch Operations

    func applyChanges(_ changes: [Change]) async throws {
        for change in changes {
            guard let item = try await fetchItem(id: change.item.id) else {
                continue // Skip if item no longer exists
            }

            switch change.action {
            case .protected:
                // No changes needed
                break

            case .resized(let newDuration):
                item.durationMinutes = newDuration
                item.touch()

            case .moved(let newStartTime):
                item.startTime = newStartTime
                item.touch()

            case .movedAndResized(let newStartTime, let newDuration):
                item.startTime = newStartTime
                item.durationMinutes = newDuration
                item.touch()

            case .deferred(let newDate):
                item.scheduledDate = newDate.startOfDay
                item.startTime = newDate
                item.touch()

            case .pooled:
                // Mark for flexible scheduling - could add a flag
                item.touch()

            case .requiresUserDecision:
                // Don't auto-apply - requires user input
                break
            }
        }

        try save()
    }

    func markCompleted(_ item: ScheduleItem) async throws {
        item.isCompleted = true
        item.touch()
        try save()
    }

    func markIncomplete(_ item: ScheduleItem) async throws {
        item.isCompleted = false
        item.touch()
        try save()
    }

    // MARK: - Private

    private func save() throws {
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.saveFailed(error)
        }
    }
}
