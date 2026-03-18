import Foundation
import SwiftData

/// Library definition for a reusable identity habit.
/// Used as a template that can be picked when scheduling a habit on the Today tab.
@Model final class HabitDefinition {
    var id: UUID
    var name: String
    var iconName: String          // SF Symbol name
    var colorHex: String          // hex string e.g. "#8B5CF6"
    var defaultDurationMinutes: Int
    var minimumDurationMinutes: Int   // always compressible
    var preferredHour: Int?           // optional scheduling hint
    var notes: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "heart.fill",
        colorHex: String = "#8B5CF6",
        defaultDurationMinutes: Int = 30,
        minimumDurationMinutes: Int = 10,
        preferredHour: Int? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.defaultDurationMinutes = defaultDurationMinutes
        self.minimumDurationMinutes = minimumDurationMinutes
        self.preferredHour = preferredHour
        self.notes = notes
        self.createdAt = Date()
    }
}
