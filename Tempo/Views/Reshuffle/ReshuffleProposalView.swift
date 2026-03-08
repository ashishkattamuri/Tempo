import SwiftUI
import SwiftData

/// View displaying proposed schedule adjustments for user approval.
struct ReshuffleProposalView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sleepManager: SleepManager
    @Query private var allItems: [ScheduleItem]

    let selectedDate: Date
    let onApply: () -> Void
    let onCancel: () -> Void

    @State private var result: ReshuffleResult?
    @State private var isLoading = true
    @State private var skippedChangeIds: Set<UUID> = []
    /// Maps a `.requiresUserDecision` Change ID → the option the user tapped.
    @State private var selectedOptionByChangeId: [UUID: Change.UserOption] = [:]

    // Apple Intelligence — parallel AI plan
    @State private var aiChanges: [Change]?       // AI-proposed changes (nil = not ready yet)
    @State private var aiSummary: String?
    @State private var aiEncouragement: String?
    @State private var isEnhancing = false
    @State private var showingAIProposal = false  // true = user switched to the AI plan

    /// The active set of changes to display and apply — switches between engine and AI plan.
    private var displayResult: ReshuffleResult? {
        guard let result else { return nil }
        if showingAIProposal, let aiChanges, !aiChanges.isEmpty {
            // Merge AI changes with any non-negotiable items the engine flagged
            // (AI only handles flexible/habit tasks, not user-decision items)
            let decisionItems = result.itemsRequiringDecision
            return ReshuffleResult(changes: aiChanges + decisionItems, summary: aiSummary ?? result.summary)
        }
        return result
    }

    private var itemsForDate: [ScheduleItem] {
        allItems.filter { $0.scheduledDate.isSameDay(as: selectedDate) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if let result = result {
                    if hasActionableChanges(result) {
                        proposalContent(result)
                    } else {
                        noChangesView
                    }
                } else {
                    errorView
                }
            }
            .navigationTitle("Fix My Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
            .onAppear(perform: analyzeSchedule)
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
            Text("Looking at your schedule...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noChangesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(.green)

            VStack(spacing: 6) {
                Text("You're all set")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("No adjustments needed for today.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Done", action: onCancel)
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Couldn't read your schedule")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button("Try Again", action: analyzeSchedule)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Proposal Content

    private func proposalContent(_ result: ReshuffleResult) -> some View {
        let displayed = displayResult ?? result
        return VStack(spacing: 0) {
            statBar(displayed)
            Divider()
            if isEnhancing || aiChanges != nil {
                aiInsightBanner
                Divider()
            }
            changesList(displayed)
            actionBar(displayed)
        }
    }

    @ViewBuilder
    private var aiInsightBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.subheadline)
                .foregroundStyle(.indigo)
                .frame(width: 20)

            if isEnhancing {
                Text("Apple Intelligence is planning your day...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if aiChanges != nil {
                VStack(alignment: .leading, spacing: 6) {
                    if let summary = aiSummary {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    if let encouragement = aiEncouragement {
                        Text(encouragement)
                            .font(.caption)
                            .foregroundStyle(.indigo)
                            .fontWeight(.medium)
                    }
                    Button(showingAIProposal ? "Switch to standard plan" : "Switch to Apple Intelligence plan") {
                        showingAIProposal.toggle()
                        skippedChangeIds = []
                        selectedOptionByChangeId = [:]
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(showingAIProposal ? Color.secondary : Color.indigo)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.indigo.opacity(0.06))
    }

    /// A compact row of chips summarising the counts (Moved · Adjusted · Deferred)
    private func statBar(_ result: ReshuffleResult) -> some View {
        let movedOnly = result.movedChanges.filter { if case .moved = $0.action { return true }; return false }
        let chips: [(String, String, Color)] = [
            ("arrow.right.circle.fill", "\(movedOnly.count) to reschedule", .blue),
            ("arrow.down.right.and.arrow.up.left", "\(result.resizedCount) to shorten", .orange),
            ("calendar.badge.clock",  "\(result.deferredCount) to defer",   .purple),
        ].filter { $0.1.first != "0" }   // hide zero-count chips

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(chips, id: \.1) { icon, label, color in
                    Label(label, systemImage: icon)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(color.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }

    private func changesList(_ result: ReshuffleResult) -> some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {

                // Items requiring user decision — rendered as UserDecisionView cards
                if !result.itemsRequiringDecision.isEmpty {
                    decisionSection(result.itemsRequiringDecision)
                }

                // Moved items
                let movedOnly = result.movedChanges.filter {
                    if case .moved = $0.action { return true }; return false
                }
                if !movedOnly.isEmpty {
                    changeSection(
                        title: "Reschedule to Later Today",
                        icon: "arrow.right.circle.fill",
                        color: .blue,
                        changes: movedOnly
                    )
                }

                // Adjusted (resized) items
                if !result.resizedChanges.isEmpty {
                    changeSection(
                        title: "Shorten Slightly",
                        icon: "arrow.down.right.and.arrow.up.left",
                        color: .orange,
                        changes: result.resizedChanges
                    )
                }

                // Deferred items
                if !result.deferredChanges.isEmpty {
                    changeSection(
                        title: "Defer to Tomorrow",
                        icon: "calendar.badge.clock",
                        color: .purple,
                        changes: result.deferredChanges
                    )
                }
            }
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func decisionSection(_ changes: [Change]) -> some View {
        Section {
            VStack(spacing: 12) {
                ForEach(changes) { change in
                    UserDecisionView(
                        change: change,
                        selectedOptionId: selectedOptionByChangeId[change.id]?.id
                    ) { option in
                        // Store the tapped option for apply-time resolution
                        selectedOptionByChangeId[change.id] = option
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 8)
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                Text("Needs Your Input")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))
        }
    }

    private func changeSection(title: String, icon: String, color: Color, changes: [Change]) -> some View {
        Section {
            VStack(spacing: 0) {
                ForEach(changes) { change in
                    ChangeRowView(
                        change: change,
                        isSkipped: skippedChangeIds.contains(change.id),
                        onToggle: {
                            if skippedChangeIds.contains(change.id) {
                                skippedChangeIds.remove(change.id)
                            } else {
                                skippedChangeIds.insert(change.id)
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    if change.id != changes.last?.id {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        } header: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))
        }
    }

    private func actionBar(_ result: ReshuffleResult) -> some View {
        let actionable = result.changes.filter { if case .protected = $0.action { return false }; return true }
        let selectedCount = actionable.filter { !skippedChangeIds.contains($0.id) }.count
        let hasSkipped = !skippedChangeIds.isEmpty && skippedChangeIds.intersection(Set(actionable.map(\.id))).count > 0

        return VStack(spacing: 0) {
            Divider()
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text("Not Now")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        applyChanges(actionable.filter { !skippedChangeIds.contains($0.id) })
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "wand.and.stars")
                            Text(hasSkipped ? "Apply (\(selectedCount))" : "Apply All")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(selectedCount > 0 ? Color.accentColor : Color(.systemGray4))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedCount == 0)
                }

                if hasSkipped {
                    Button(action: { applyChanges(actionable) }) {
                        Text("Apply all \(actionable.count) changes")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Helpers

    private func hasActionableChanges(_ result: ReshuffleResult) -> Bool {
        result.changes.contains { change in
            if case .protected = change.action { return false }
            return true
        }
    }

    // MARK: - Actions

    private func analyzeSchedule() {
        isLoading = true
        aiChanges = nil
        aiSummary = nil
        aiEncouragement = nil
        showingAIProposal = false
        Task { @MainActor in
            let engine = ReshuffleEngine()
            engine.sleepManager = sleepManager
            let engineResult = engine.analyze(items: Array(allItems), for: selectedDate)
            result = engineResult
            isLoading = false

            await proposeWithAI(engineChanges: engineResult.changes, allItems: Array(allItems))
        }
    }

    private func proposeWithAI(engineChanges: [Change], allItems: [ScheduleItem]) async {
        guard #available(iOS 26, *) else { return }

        // Only pass the actionable (non-protected, non-decision) overdue tasks to the AI
        let overdueTasks = engineChanges.compactMap { change -> ScheduleItem? in
            switch change.action {
            case .protected, .requiresUserDecision: return nil
            default: return change.item
            }
        }
        guard !overdueTasks.isEmpty else { return }

        isEnhancing = true
        if let proposal = await SchedulingAssistant.shared.proposeReschedule(
            overdueTasks: overdueTasks,
            allItems: allItems,
            date: selectedDate,
            sleepManager: sleepManager
        ) {
            let converted = SchedulingAssistant.shared.convertToChanges(
                proposal: proposal,
                overdueTasks: overdueTasks,
                date: selectedDate,
                allItems: allItems,
                sleepManager: sleepManager
            )
            aiChanges = converted
            aiSummary = proposal.summary
            aiEncouragement = proposal.encouragement
            // Auto-switch to AI plan once it's ready
            if !converted.isEmpty {
                showingAIProposal = true
                skippedChangeIds = []
                selectedOptionByChangeId = [:]
            }
        }
        isEnhancing = false
    }

    private func applyChanges(_ changes: [Change]) {
        Task { @MainActor in
            let repository = SwiftDataScheduleRepository(modelContext: modelContext)
            var resolvedChanges: [Change] = []

            for change in changes {
                if case .requiresUserDecision = change.action {
                    guard let selected = selectedOptionByChangeId[change.id] else {
                        continue  // User made no decision — skip
                    }

                    if let newTime = selected.newStartTime {
                        // Slot option — move the item to the chosen time
                        resolvedChanges.append(Change(
                            id: change.id,
                            item: change.item,
                            action: .moved(newStartTime: newTime),
                            reason: change.reason
                        ))
                    } else if selected.title == "Defer to tomorrow" {
                        // Defer option — keep the same clock time but on tomorrow's date
                        let cal = Calendar.current
                        let tomorrow = cal.date(byAdding: .day, value: 1, to: change.item.scheduledDate) ?? change.item.scheduledDate
                        var comps = cal.dateComponents([.year, .month, .day], from: tomorrow)
                        let timeComps = cal.dateComponents([.hour, .minute], from: change.item.startTime)
                        comps.hour = timeComps.hour
                        comps.minute = timeComps.minute
                        let deferDate = cal.date(from: comps) ?? tomorrow
                        resolvedChanges.append(Change(
                            id: change.id,
                            item: change.item,
                            action: .deferred(newDate: deferDate),
                            reason: change.reason
                        ))
                    } else if selected.title == "Mark as done" {
                        // Complete the live SwiftData item directly
                        if let liveItem = allItems.first(where: { $0.id == change.item.id }) {
                            liveItem.isCompleted = true
                            liveItem.touch()
                        }
                        // No Change entry needed — already mutated in place
                    }
                } else {
                    resolvedChanges.append(change)
                }
            }

            try? await repository.applyChanges(resolvedChanges)
            onApply()
        }
    }
}

// MARK: - Previews

#Preview("Reshuffle Proposal") {
    ReshuffleProposalView(
        selectedDate: Date(),
        onApply: {},
        onCancel: {}
    )
    .modelContainer(for: ScheduleItem.self, inMemory: true)
}
