import SwiftUI
import SwiftData
import os.log

private let conflictLog = OSLog(subsystem: "com.tempo.app", category: "ConflictResolution")

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
        switch action {
        case .moveConflicting(let newTime):
            // Find and move the conflicting item
            if let conflictingItem = allItems.first(where: { $0.id == resolution.conflictingItem.id }) {
                conflictingItem.startTime = newTime
                conflictingItem.touch()
                try? modelContext.save()
            }

        case .moveNew(let newTime):
            // Move the new item - this resolves ALL conflicts at once
            if let newItemId = savedItem?.id,
               let newItem = allItems.first(where: { $0.id == newItemId }) {
                newItem.startTime = newTime
                newItem.touch()
                try? modelContext.save()
            }
            // Clear ALL resolutions and dismiss since moving the new item fixes everything
            conflictResolutions.removeAll()
            showingConflictResolution = false
            savedItem = nil
            return

        case .keepBoth:
            // Just skip this conflict
            break

        case .deleteConflicting:
            if let conflictingItem = allItems.first(where: { $0.id == resolution.conflictingItem.id }) {
                modelContext.delete(conflictingItem)
                try? modelContext.save()
            }
        }

        // Recalculate remaining conflicts with updated schedule
        recalculateRemainingConflicts(excludingResolved: resolution)
    }

    private func recalculateRemainingConflicts(excludingResolved resolved: ConflictResolution) {
        guard let newItem = savedItem,
              let actualNewItem = allItems.first(where: { $0.id == newItem.id }) else {
            conflictResolutions.removeAll()
            showingConflictResolution = false
            savedItem = nil
            return
        }

        // Fetch fresh items from the model context to get the latest state
        let freshItems = fetchFreshItems(for: actualNewItem.scheduledDate)

        // Get remaining conflicting item IDs (exclude the one we just resolved)
        let remainingConflictIds = conflictResolutions
            .filter { $0.id != resolved.id }
            .map { $0.conflictingItem.id }

        // Check which items still actually conflict with the new item (using fresh data)
        let stillConflicting = freshItems.filter { item in
            remainingConflictIds.contains(item.id) &&
            !item.isCompleted &&
            actualNewItem.overlaps(with: item)
        }

        if stillConflicting.isEmpty {
            // No more conflicts - we're done
            conflictResolutions.removeAll()
            showingConflictResolution = false
            savedItem = nil
        } else {
            // Recalculate resolutions with fresh slot suggestions using fresh items
            conflictResolutions = reshuffleEngine.suggestResolution(
                newItem: actualNewItem,
                conflictingItems: stillConflicting,
                allItems: freshItems
            )
        }
    }

    private func fetchFreshItems(for date: Date) -> [ScheduleItem] {
        let startOfDay = date.startOfDay
        let endOfDay = date.endOfDay

        let predicate = #Predicate<ScheduleItem> { item in
            item.scheduledDate >= startOfDay && item.scheduledDate <= endOfDay
        }

        let descriptor = FetchDescriptor<ScheduleItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime)]
        )

        let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            return f
        }()

        do {
            let items = try modelContext.fetch(descriptor)
            os_log("Fetched %d items for date", log: conflictLog, type: .debug, items.count)
            for item in items {
                os_log("  - %{public}@ [%{public}@]: %{public}@ - %{public}@ (completed: %d)", log: conflictLog, type: .debug, item.title, item.category.displayName, timeFormatter.string(from: item.startTime), timeFormatter.string(from: item.endTime), item.isCompleted ? 1 : 0)
            }
            return items
        } catch {
            os_log("Error fetching, using allItems fallback", log: conflictLog, type: .error)
            return Array(allItems.filter { $0.scheduledDate.isSameDay(as: date) })
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ScheduleItem.self, inMemory: true)
}
