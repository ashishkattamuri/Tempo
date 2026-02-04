import Foundation
import SwiftData
import Observation

/// ViewModel for task creation and editing.
/// Handles form validation and save operations.
@MainActor
@Observable
final class TaskEditViewModel {
    // MARK: - Dependencies

    private let repository: ScheduleRepository
    private let existingItem: ScheduleItem?

    // MARK: - Form State

    var title: String = ""
    var category: TaskCategory = .flexibleTask
    var startTime: Date = Date()
    var durationMinutes: Int = Constants.defaultTaskDurationMinutes
    var minimumDurationMinutes: Int? = nil
    var notes: String = ""
    var isEveningTask: Bool = false
    var isGentleTask: Bool = false

    // MARK: - UI State

    var isSaving = false
    var error: Error?

    // MARK: - Computed Properties

    var isEditing: Bool {
        existingItem != nil
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespaces)
    }

    var canCompress: Bool {
        category == .identityHabit
    }

    var isCompressible: Bool {
        minimumDurationMinutes != nil
    }

    var compressionEnabled: Bool {
        get { minimumDurationMinutes != nil }
        set {
            if newValue {
                minimumDurationMinutes = min(durationMinutes, Constants.defaultIdentityHabitMinimumMinutes)
            } else {
                minimumDurationMinutes = nil
            }
        }
    }

    var durationOptions: [Int] {
        stride(from: 5, through: 480, by: 5).map { $0 }
    }

    var minimumDurationOptions: [Int] {
        stride(from: 5, through: durationMinutes, by: 5).map { $0 }
    }

    // MARK: - Validation

    var validationErrors: [String] {
        var errors: [String] = []

        if trimmedTitle.isEmpty {
            errors.append("Title is required")
        }

        if durationMinutes < Constants.minimumTaskDurationMinutes {
            errors.append("Duration must be at least \(Constants.minimumTaskDurationMinutes) minutes")
        }

        if let min = minimumDurationMinutes, min > durationMinutes {
            errors.append("Minimum duration cannot exceed full duration")
        }

        return errors
    }

    // MARK: - Initialization

    init(repository: ScheduleRepository, existingItem: ScheduleItem? = nil) {
        self.repository = repository
        self.existingItem = existingItem

        if let item = existingItem {
            loadFromItem(item)
        }
    }

    // MARK: - Data Operations

    private func loadFromItem(_ item: ScheduleItem) {
        title = item.title
        category = item.category
        startTime = item.startTime
        durationMinutes = item.durationMinutes
        minimumDurationMinutes = item.minimumDurationMinutes
        notes = item.notes ?? ""
        isEveningTask = item.isEveningTask
        isGentleTask = item.isGentleTask
    }

    func save(for scheduledDate: Date) async throws -> ScheduleItem {
        guard isValid else {
            throw ValidationError.invalidInput(validationErrors.first ?? "Invalid input")
        }

        isSaving = true
        error = nil

        defer { isSaving = false }

        if let existingItem = existingItem {
            // Update existing
            existingItem.title = trimmedTitle
            existingItem.category = category
            existingItem.startTime = startTime
            existingItem.durationMinutes = durationMinutes
            existingItem.minimumDurationMinutes = canCompress ? minimumDurationMinutes : nil
            existingItem.notes = notes.isEmpty ? nil : notes
            existingItem.isEveningTask = isEveningTask
            existingItem.isGentleTask = isGentleTask
            existingItem.touch()

            try await repository.update(existingItem)
            return existingItem
        } else {
            // Create new
            let newItem = ScheduleItem(
                title: trimmedTitle,
                category: category,
                startTime: startTime,
                durationMinutes: durationMinutes,
                minimumDurationMinutes: canCompress ? minimumDurationMinutes : nil,
                notes: notes.isEmpty ? nil : notes,
                scheduledDate: scheduledDate,
                isEveningTask: isEveningTask,
                isGentleTask: isGentleTask
            )

            try await repository.create(newItem)
            return newItem
        }
    }

    func delete() async throws {
        guard let existingItem = existingItem else { return }

        isSaving = true
        error = nil

        defer { isSaving = false }

        try await repository.delete(existingItem)
    }

    // MARK: - Helpers

    func updateEveningStatus() {
        // Auto-detect evening based on start time
        isEveningTask = startTime.isEvening
    }

    func resetToDefaults() {
        title = ""
        category = .flexibleTask
        startTime = Date()
        durationMinutes = Constants.defaultTaskDurationMinutes
        minimumDurationMinutes = nil
        notes = ""
        isEveningTask = false
        isGentleTask = false
    }
}

// MARK: - Errors

enum ValidationError: LocalizedError {
    case invalidInput(String)

    var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return message
        }
    }
}
