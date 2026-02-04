import Foundation

/// Protocol defining CRUD operations for schedule items.
/// Enables dependency injection and testability.
protocol ScheduleRepository {
    /// Fetch all items for a specific date
    func fetchItems(for date: Date) async throws -> [ScheduleItem]

    /// Fetch all items in a date range
    func fetchItems(from startDate: Date, to endDate: Date) async throws -> [ScheduleItem]

    /// Fetch a single item by ID
    func fetchItem(id: UUID) async throws -> ScheduleItem?

    /// Fetch all incomplete items for today
    func fetchIncompleteItems(for date: Date) async throws -> [ScheduleItem]

    /// Fetch evening items for a specific date
    func fetchEveningItems(for date: Date) async throws -> [ScheduleItem]

    /// Create a new item
    func create(_ item: ScheduleItem) async throws

    /// Update an existing item
    func update(_ item: ScheduleItem) async throws

    /// Delete an item
    func delete(_ item: ScheduleItem) async throws

    /// Delete an item by ID
    func delete(id: UUID) async throws

    /// Apply a batch of changes from reshuffle
    func applyChanges(_ changes: [Change]) async throws

    /// Mark an item as completed
    func markCompleted(_ item: ScheduleItem) async throws

    /// Mark an item as incomplete
    func markIncomplete(_ item: ScheduleItem) async throws
}

// MARK: - Repository Errors

enum RepositoryError: LocalizedError {
    case itemNotFound(UUID)
    case saveFailed(Error)
    case fetchFailed(Error)
    case deleteFailed(Error)
    case invalidData(String)

    var errorDescription: String? {
        switch self {
        case .itemNotFound(let id):
            return "Item with ID \(id) not found"
        case .saveFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete: \(error.localizedDescription)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        }
    }
}
