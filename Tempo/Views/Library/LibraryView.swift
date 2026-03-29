import SwiftUI

/// Root Library tab — segmented picker between Habits, Goals, and Tasks.
struct LibraryView: View {
    @State private var selectedSegment: LibrarySegment = .tasks

    enum LibrarySegment: String, CaseIterable {
        case tasks  = "Tasks"
        case habits = "Habits"
        case goals  = "Goals"
    }

    var body: some View {
        NavigationStack {
            Group {
                switch selectedSegment {
                case .habits: HabitLibraryView()
                case .goals:  GoalLibraryView()
                case .tasks:  TaskLibraryView()
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Section", selection: $selectedSegment) {
                        ForEach(LibrarySegment.allCases, id: \.self) { seg in
                            Text(seg.rawValue).tag(seg)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 280)
                }
            }
        }
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: [HabitDefinition.self, GoalDefinition.self, TaskDefinition.self], inMemory: true)
}
