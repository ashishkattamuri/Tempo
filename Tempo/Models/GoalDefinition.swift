import Foundation
import SwiftData

/// Library definition for a reusable optional goal.
/// Used as a template that can be picked when scheduling a goal on the Today tab.
@Model final class GoalDefinition {
    var id: UUID
    var name: String
    var iconName: String          // SF Symbol name
    var colorHex: String          // hex string e.g. "#10B981"
    var defaultDurationMinutes: Int
    var notes: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "star.fill",
        colorHex: String = "#10B981",
        defaultDurationMinutes: Int = 30,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.defaultDurationMinutes = defaultDurationMinutes
        self.notes = notes
        self.createdAt = Date()
    }
}
