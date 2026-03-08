import Foundation
import FamilyControls

/// Represents a named set of apps/categories to block during a focus session.
struct FocusGroup: Codable, Identifiable {
    let id: UUID
    var name: String
    var symbol: String
    var selection: FamilyActivitySelection

    init(
        id: UUID = UUID(),
        name: String,
        symbol: String = "moon.circle.fill",
        selection: FamilyActivitySelection = FamilyActivitySelection()
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.selection = selection
    }

    /// Total number of blocked items (app tokens + category tokens)
    var blockedItemCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count
    }

    var blockedItemDescription: String {
        let count = blockedItemCount
        if count == 0 {
            return "No apps selected"
        } else if count == 1 {
            return "1 item blocked"
        } else {
            return "\(count) items blocked"
        }
    }
}
