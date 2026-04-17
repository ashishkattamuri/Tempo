import SwiftUI
import SwiftData
import os.log

private let conflictLog = OSLog(subsystem: "com.tempo.app", category: "ConflictResolution")

/// Root navigation view for the Tempo app.
/// Uses a 4-tab layout: Today · Library · Insights · Settings.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sleepManager: SleepManager
    @EnvironmentObject private var compensationTracker: CompensationTracker
    @Query private var allItems: [ScheduleItem]
    @Query(sort: \TaskDefinition.createdAt)  private var taskDefs: [TaskDefinition]
    @Query(sort: \HabitDefinition.createdAt) private var habitDefs: [HabitDefinition]
    @Query(sort: \GoalDefinition.createdAt)  private var goalDefs: [GoalDefinition]
    @State private var selectedDate = Date()
    @State private var showingTaskEdit = false
    @State private var showingReshuffle = false
    @State private var showingSettings = false
    @State private var showingCompensation = false
    @State private var editingItem: ScheduleItem?
    @State private var selectedTab: Int = 0

    // Voice agent
    @StateObject private var voiceAgent = VoiceSchedulingAgent(sleepManager: nil)
    @State private var showVoiceOverlay = false

    // Conflict detection state
    @State private var pendingConflictCheck: ScheduleItem?
    @State private var showingConflictResolution = false
    @State private var conflictResolutions: [ConflictResolution] = []
    @State private var savedItem: ScheduleItem?

    // Sleep overlap state
    @State private var showingSleepOverlap = false
    @State private var sleepOverlapItem: ScheduleItem?
    @State private var sleepEarlierSuggestion: Date?
    @State private var sleepNextSlotSuggestion: Date?

    @State private var reshuffleEngine = ReshuffleEngine()

    var body: some View {
        TabView(selection: $selectedTab) {
            // MARK: Tab 1 — Today
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
            }
            .tabItem {
                Label("Today", systemImage: "calendar")
            }
            .tag(0)

            // MARK: Tab 2 — Library
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical.fill")
                }
                .tag(1)

            // MARK: Tab 3 — Insights
            InsightsTabView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.fill")
                }
                .tag(2)

            // MARK: Tab 4 — Settings
            NavigationStack {
                SettingsMenuView(
                    sleepManager: sleepManager,
                    compensationTracker: compensationTracker,
                    onDismiss: {}
                )
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(3)
        }
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
        .sheet(isPresented: $showingSleepOverlap) {
            if let item = sleepOverlapItem {
                SleepOverlapSheet(
                    item: item,
                    earlierTime: sleepEarlierSuggestion,
                    nextAvailableTime: sleepNextSlotSuggestion,
                    onMoveEarlier: {
                        if let newTime = sleepEarlierSuggestion {
                            applySleepSuggestion(to: item, newStartTime: newTime)
                        }
                        showingSleepOverlap = false
                    },
                    onMoveToNextSlot: {
                        if let newTime = sleepNextSlotSuggestion {
                            applySleepSuggestion(to: item, newStartTime: newTime)
                        }
                        showingSleepOverlap = false
                    },
                    onKeep: {
                        showingSleepOverlap = false
                    }
                )
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingReshuffle) {
            ReshuffleProposalView(
                selectedDate: selectedDate,
                onApply: { showingReshuffle = false },
                onCancel: { showingReshuffle = false }
            )
        }
        .sheet(isPresented: $showingCompensation) {
            CompensationView(compensationTracker: compensationTracker)
        }
        .overlay(alignment: .bottomTrailing) {
            if FeatureFlags.voiceAgent {
                FloatingMicButton(agent: voiceAgent) {
                    switch voiceAgent.state {
                    case .listening:
                        voiceAgent.stopListening()
                    case .idle, .error:
                        showVoiceOverlay = true
                        voiceAgent.startConversation(
                            scheduleItems:    Array(allItems),
                            taskDefinitions:  Array(taskDefs),
                            habitDefinitions: Array(habitDefs),
                            goalDefinitions:  Array(goalDefs)
                        )
                    case .processing, .responding:
                        break
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 90)
            }
        }
        .sheet(isPresented: $showVoiceOverlay) {
            if FeatureFlags.voiceAgent {
                VoiceAgentOverlay(
                    agent: voiceAgent,
                    onDismiss: {
                        voiceAgent.endConversation()
                        showVoiceOverlay = false
                    }
                )
                .presentationDetents([.large, .medium])
                .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: voiceAgent.pendingAction) { _, action in
            guard let action else { return }
            switch action {
            case .createTask(let title, let startTime, let durationMinutes, let category, let notes, let defId):
                let item = ScheduleItem(
                    title: title, category: category,
                    startTime: startTime, durationMinutes: durationMinutes,
                    notes: notes, taskDefinitionId: defId
                )
                modelContext.insert(item)
                try? modelContext.save()
                selectedDate = startTime
                selectedTab  = 0

            case .rescheduleTask(let id, let newStartTime):
                if let item = allItems.first(where: { $0.id == id }) {
                    item.startTime    = newStartTime
                    item.scheduledDate = Calendar.current.startOfDay(for: newStartTime)
                    item.touch()
                    try? modelContext.save()
                }

            case .completeTask(let id):
                if let item = allItems.first(where: { $0.id == id }) {
                    item.isCompleted = true
                    item.touch()
                    try? modelContext.save()
                }

            case .deleteTask(let id):
                if let item = allItems.first(where: { $0.id == id }) {
                    modelContext.delete(item)
                    try? modelContext.save()
                }
            }
            voiceAgent.pendingAction = nil
            voiceAgent.refreshSchedule(Array(allItems))
        }
        .onAppear {
            reshuffleEngine.sleepManager = sleepManager
            voiceAgent.sleepManager = sleepManager
            Task { await voiceAgent.setup() }
        }
        .onDisappear {
            voiceAgent.teardown()
        }
    }

    // MARK: - Conflict Detection

    private func checkForConflicts(newItem: ScheduleItem) {
        let existingItems = allItems.filter { item in
            item.id != newItem.id &&
            item.scheduledDate.isSameDay(as: newItem.scheduledDate) &&
            !item.isCompleted
        }

        let conflicts = existingItems.filter { existing in
            newItem.overlaps(with: existing)
        }

        if !conflicts.isEmpty {
            savedItem = newItem
            conflictResolutions = reshuffleEngine.suggestResolution(
                newItem: newItem,
                conflictingItems: conflicts,
                allItems: Array(allItems)
            )
            showingConflictResolution = true
            return
        }

        checkForSleepOverlap(newItem: newItem)
    }

    private func checkForSleepOverlap(newItem: ScheduleItem) {
        guard sleepManager.isEnabled else { return }
        guard sleepManager.doesRangeOverlapSleep(start: newItem.startTime, end: newItem.endTime) else { return }
        guard let range = sleepManager.getSleepBlockedRange(for: newItem.scheduledDate) else { return }

        let earlierStart = range.bufferStart.addingTimeInterval(-Double(newItem.durationMinutes * 60))
        let calendar = Calendar.current
        let dayStart = calendar.date(bySettingHour: 5, minute: 0, second: 0, of: newItem.scheduledDate) ?? newItem.scheduledDate
        sleepEarlierSuggestion = (earlierStart >= dayStart && earlierStart > Date()) ? earlierStart : nil
        sleepNextSlotSuggestion = findFirstFreeSlotAfterWake(wakeTime: range.wakeTime, durationMinutes: newItem.durationMinutes)

        sleepOverlapItem = newItem
        showingSleepOverlap = true
    }

    private func findFirstFreeSlotAfterWake(wakeTime: Date, durationMinutes: Int) -> Date {
        let wakeDay = Calendar.current.startOfDay(for: wakeTime)
        let duration = TimeInterval(durationMinutes * 60)
        let itemsOnWakeDay = allItems
            .filter { $0.scheduledDate.isSameDay(as: wakeDay) && !$0.isCompleted }
            .sorted { $0.startTime < $1.startTime }
        var candidate = wakeTime
        for item in itemsOnWakeDay {
            if item.endTime <= candidate { continue }
            if item.startTime >= candidate.addingTimeInterval(duration) { break }
            candidate = item.endTime
        }
        return candidate
    }

    private func applySleepSuggestion(to item: ScheduleItem, newStartTime: Date) {
        guard let liveItem = allItems.first(where: { $0.id == item.id }) else { return }
        liveItem.startTime = newStartTime
        liveItem.scheduledDate = Calendar.current.startOfDay(for: newStartTime)
        liveItem.touch()
        try? modelContext.save()
        sleepOverlapItem = nil
    }

    private func applyResolution(_ resolution: ConflictResolution, action: ConflictAction) {
        switch action {
        case .moveConflicting(let newTime):
            if let conflictingItem = allItems.first(where: { $0.id == resolution.conflictingItem.id }) {
                conflictingItem.startTime = newTime
                conflictingItem.scheduledDate = Calendar.current.startOfDay(for: newTime)
                conflictingItem.touch()
                try? modelContext.save()
            }

        case .moveNew(let newTime):
            if let newItemId = savedItem?.id,
               let newItem = allItems.first(where: { $0.id == newItemId }) {
                newItem.startTime = newTime
                newItem.scheduledDate = Calendar.current.startOfDay(for: newTime)
                newItem.touch()
                try? modelContext.save()
            }
            conflictResolutions.removeAll()
            showingConflictResolution = false
            savedItem = nil
            return

        case .keepBoth:
            break

        case .deleteConflicting:
            if let conflictingItem = allItems.first(where: { $0.id == resolution.conflictingItem.id }) {
                modelContext.delete(conflictingItem)
                try? modelContext.save()
            }
        }

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

        let freshItems = fetchFreshItems(for: actualNewItem.scheduledDate)
        let remainingConflictIds = conflictResolutions
            .filter { $0.id != resolved.id }
            .map { $0.conflictingItem.id }

        let stillConflicting = freshItems.filter { item in
            remainingConflictIds.contains(item.id) &&
            !item.isCompleted &&
            actualNewItem.overlaps(with: item)
        }

        if stillConflicting.isEmpty {
            conflictResolutions.removeAll()
            showingConflictResolution = false
            savedItem = nil
        } else {
            conflictResolutions = reshuffleEngine.suggestResolution(
                newItem: actualNewItem,
                conflictingItems: stillConflicting,
                allItems: freshItems
            )
        }
    }

    private func fetchFreshItems(for date: Date) -> [ScheduleItem] {
        let startOfDay = date.startOfDay
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: date)?.endOfDay ?? date.endOfDay

        let predicate = #Predicate<ScheduleItem> { item in
            item.scheduledDate >= startOfDay && item.scheduledDate <= endOfWeek
        }

        let descriptor = FetchDescriptor<ScheduleItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            return Array(allItems.filter { $0.scheduledDate.isSameDay(as: date) })
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ScheduleItem.self, HabitDefinition.self, GoalDefinition.self], inMemory: true)
        .environmentObject(SleepManager())
        .environmentObject(CompensationTracker())
        .environmentObject(FocusBlockManager())
}
