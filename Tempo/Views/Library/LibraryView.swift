import SwiftUI

/// Root Library tab — segmented picker between Habits and Goals.
struct LibraryView: View {
    @State private var selectedSegment: LibrarySegment = .habits

    enum LibrarySegment: String, CaseIterable {
        case habits = "Habits"
        case goals  = "Goals"
    }

    var body: some View {
        NavigationStack {
            Group {
                switch selectedSegment {
                case .habits: HabitLibraryView()
                case .goals:  GoalLibraryView()
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
                    .frame(width: 200)
                }
            }
        }
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: [HabitDefinition.self, GoalDefinition.self], inMemory: true)
}
