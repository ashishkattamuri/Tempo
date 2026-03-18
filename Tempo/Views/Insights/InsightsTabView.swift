import SwiftUI

/// Tab wrapper that promotes WeeklyRetrospectiveView to a top-level tab.
struct InsightsTabView: View {
    var body: some View {
        NavigationStack {
            WeeklyRetrospectiveView()
        }
    }
}

#Preview {
    InsightsTabView()
        .modelContainer(for: ScheduleItem.self, inMemory: true)
}
