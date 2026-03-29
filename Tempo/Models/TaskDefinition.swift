import Foundation
import SwiftData

/// A to-do style task in the library, optionally with a deadline.
/// Can be recommended for scheduling into free slots on the timeline.
@Model
final class TaskDefinition {
    var id: UUID
    var title: String
    var iconName: String
    var colorHex: String
    var durationMinutes: Int
    var deadline: Date?
    var isCompleted: Bool
    var notes: String?
    var createdAt: Date

    init(
        title: String,
        iconName: String = "checkmark.circle.fill",
        colorHex: String = "#3B82F6",
        durationMinutes: Int = 30,
        deadline: Date? = nil,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.iconName = iconName
        self.colorHex = colorHex
        self.durationMinutes = durationMinutes
        self.deadline = deadline
        self.isCompleted = false
        self.notes = notes
        self.createdAt = Date()
    }
}
