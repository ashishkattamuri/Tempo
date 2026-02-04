import SwiftUI
import SwiftData

/// Root navigation view for the Tempo app.
/// Manages navigation between schedule view and other screens.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [ScheduleItem]
    @State private var selectedDate = Date()
    @State private var showingTaskEdit = false
    @State private var showingReshuffle = false
    @State private var editingItem: ScheduleItem?

    // Conflict detection state
    @State private var pendingConflictCheck: ScheduleItem?
    @State private var showingConflictResolution = false
    @State private var conflictResolutions: [ConflictResolution] = []
    @State private var savedItem: ScheduleItem?

    private let reshuffleEngine = ReshuffleEngine()

    var body: some View {
        NavigationStack {
            ScheduleView(
                selectedDate: $selectedDate,
                onAddTask: {
                    editingItem = nil
                    showingTaskEdit = true
                },
                onEditTask: { item in
                    editingItem = item
                    showingTaskEdit = true
                },
                onReshuffle: {
                    showingReshuffle = true
                }
            )
            .sheet(isPresented: $showingTaskEdit) {
                TaskEditView(
                    item: editingItem,
                    selectedDate: selectedDate,
                    onSave: { newItem in
                        pendingConflictCheck = newItem
                        showingTaskEdit = false
                    },
                    onCancel: {
                        showingTaskEdit = false
                    }
                )
            }
            .onChange(of: showingTaskEdit) { _, isShowing in
                if !isShowing, let newItem = pendingConflictCheck {
                    pendingConflictCheck = nil
                    // Delay to allow sheet dismiss animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        checkForConflicts(newItem: newItem)
                    }
                }
            }
            .sheet(isPresented: $showingConflictResolution) {
                if !conflictResolutions.isEmpty {
                    ConflictResolutionSheet(
                        resolutions: conflictResolutions,
                        onResolve: { resolution, action in
                            applyResolution(resolution, action: action)
                        },
                        onDismiss: {
                            showingConflictResolution = false
                            conflictResolutions = []
                        }
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showingReshuffle) {
                ReshuffleProposalView(
                    selectedDate: selectedDate,
                    onApply: {
                        showingReshuffle = false
                    },
                    onCancel: {
                        showingReshuffle = false
                    }
                )
            }
        }
    }

    // MARK: - Conflict Detection

    private func checkForConflicts(newItem: ScheduleItem) {
        // Get items for the same day as the new item, excluding the new item itself
        let existingItems = allItems.filter { item in
            item.id != newItem.id &&
            item.scheduledDate.isSameDay(as: newItem.scheduledDate) &&
            !item.isCompleted
        }

        // Find overlapping items
        let conflicts = existingItems.filter { existing in
            newItem.overlaps(with: existing)
        }

        if !conflicts.isEmpty {
            savedItem = newItem
            // Pass all items so the engine can find truly empty slots
            conflictResolutions = reshuffleEngine.suggestResolution(
                newItem: newItem,
                conflictingItems: conflicts,
                allItems: Array(allItems)
            )
            showingConflictResolution = true
        }
    }

    private func applyResolution(_ resolution: ConflictResolution, action: ConflictAction) {
        // Find the actual managed objects from allItems
        guard let conflictingItem = allItems.first(where: { $0.id == resolution.conflictingItem.id }) else {
            return
        }

        switch action {
        case .moveConflicting(let newTime):
            conflictingItem.startTime = newTime
            conflictingItem.touch()
            try? modelContext.save()

        case .moveNew(let newTime):
            if let newItemId = savedItem?.id,
               let newItem = allItems.first(where: { $0.id == newItemId }) {
                newItem.startTime = newTime
                newItem.touch()
                try? modelContext.save()
            }

        case .keepBoth:
            // Do nothing - keep overlapping
            break

        case .deleteConflicting:
            modelContext.delete(conflictingItem)
            try? modelContext.save()
        }

        // Remove this resolution from the list
        conflictResolutions.removeAll { $0.id == resolution.id }

        // If no more resolutions, dismiss
        if conflictResolutions.isEmpty {
            showingConflictResolution = false
            savedItem = nil
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ScheduleItem.self, inMemory: true)
}
