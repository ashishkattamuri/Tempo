import SwiftUI
import SwiftData

/// View displaying proposed reshuffle changes for user approval.
struct ReshuffleProposalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [ScheduleItem]

    let selectedDate: Date
    let onApply: () -> Void
    let onCancel: () -> Void

    @State private var result: ReshuffleResult?
    @State private var isLoading = true
    @State private var showingEveningSheet = false
    @State private var showingConfirmation = false

    private var itemsForDate: [ScheduleItem] {
        allItems.filter { $0.scheduledDate.isSameDay(as: selectedDate) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if let result = result {
                    if result.changes.isEmpty {
                        noChangesView
                    } else {
                        proposalContent(result)
                    }
                } else {
                    errorView
                }
            }
            .navigationTitle("Reshuffle Proposal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
            .onAppear(perform: analyzeSchedule)
            .sheet(isPresented: $showingEveningSheet) {
                if let decision = result?.eveningDecision {
                    EveningProtectionSheet(
                        decision: decision,
                        onKeepFree: {
                            showingEveningSheet = false
                            // Keep evening free - don't apply evening changes
                        },
                        onAllow: {
                            showingEveningSheet = false
                            // Allow evening tasks
                        }
                    )
                }
            }
            .confirmationDialog(
                "Apply these changes?",
                isPresented: $showingConfirmation,
                titleVisibility: .visible
            ) {
                Button("Apply Changes", action: applyChanges)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will adjust your schedule as shown. You can always undo by editing tasks manually.")
            }
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Analyzing your schedule...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var noChangesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("You're on track!")
                .font(.headline)

            Text("No changes needed for today's schedule.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Done", action: onCancel)
                .buttonStyle(.borderedProminent)
                .padding(.top)
        }
        .padding()
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundColor(.orange)

            Text("Couldn't analyze schedule")
                .font(.headline)

            Button("Try Again", action: analyzeSchedule)
                .buttonStyle(.bordered)
        }
        .padding()
    }

    private func proposalContent(_ result: ReshuffleResult) -> some View {
        VStack(spacing: 0) {
            // Summary header
            summaryHeader(result)

            // Changes list
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    // Items requiring decision first
                    if !result.itemsRequiringDecision.isEmpty {
                        Section {
                            ForEach(result.itemsRequiringDecision) { change in
                                UserDecisionView(
                                    change: change,
                                    onSelectOption: { option in
                                        // Handle user choice
                                    }
                                )
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            }
                        } header: {
                            sectionHeader(
                                title: "Needs Your Input",
                                count: result.itemsRequiringDecision.count,
                                icon: "exclamationmark.triangle.fill",
                                color: .orange
                            )
                        }
                    }

                    // Protected items
                    if !result.protectedChanges.isEmpty {
                        Section {
                            ForEach(result.protectedChanges) { change in
                                ChangeRowView(change: change)
                                    .padding(.horizontal)
                            }
                        } header: {
                            sectionHeader(
                                title: "Protected",
                                count: result.protectedCount,
                                icon: "shield.fill",
                                color: .green
                            )
                        }
                    }

                    // Adjusted items
                    if !result.resizedChanges.isEmpty {
                        Section {
                            ForEach(result.resizedChanges) { change in
                                ChangeRowView(change: change)
                                    .padding(.horizontal)
                            }
                        } header: {
                            sectionHeader(
                                title: "Adjusted",
                                count: result.resizedCount,
                                icon: "arrow.down.right.and.arrow.up.left",
                                color: .orange
                            )
                        }
                    }

                    // Moved items
                    let movedOnly = result.movedChanges.filter {
                        if case .moved = $0.action { return true }
                        return false
                    }
                    if !movedOnly.isEmpty {
                        Section {
                            ForEach(movedOnly) { change in
                                ChangeRowView(change: change)
                                    .padding(.horizontal)
                            }
                        } header: {
                            sectionHeader(
                                title: "Moved",
                                count: movedOnly.count,
                                icon: "arrow.right",
                                color: .blue
                            )
                        }
                    }

                    // Deferred items
                    if !result.deferredChanges.isEmpty {
                        Section {
                            ForEach(result.deferredChanges) { change in
                                ChangeRowView(change: change)
                                    .padding(.horizontal)
                            }
                        } header: {
                            sectionHeader(
                                title: "Deferred",
                                count: result.deferredCount,
                                icon: "calendar.badge.clock",
                                color: .purple
                            )
                        }
                    }
                }
                .padding(.bottom, 100) // Space for bottom bar
            }

            // Bottom action bar
            actionBar(result)
        }
    }

    private func summaryHeader(_ result: ReshuffleResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.summary)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if result.timeSavedMinutes > 0 {
                HStack {
                    Image(systemName: "clock.badge.checkmark")
                    Text("\(result.timeSavedMinutes) minutes saved through adjustments")
                }
                .font(.caption)
                .foregroundColor(.green)
            }

            if result.eveningProtectionTriggered {
                HStack {
                    Image(systemName: "moon.fill")
                    Text("Evening protection active")
                }
                .font(.caption)
                .foregroundColor(.purple)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
    }

    private func sectionHeader(title: String, count: Int, icon: String, color: Color) -> some View {
        ChangeSectionHeader(title: title, count: count, iconName: icon, color: color)
            .padding()
            .background(Color(.systemBackground))
    }

    private func actionBar(_ result: ReshuffleResult) -> some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 16) {
                // Cancel button
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(Constants.cornerRadius)
                }
                .buttonStyle(.plain)

                // Apply button
                Button(action: {
                    if result.eveningProtectionTriggered {
                        showingEveningSheet = true
                    } else {
                        showingConfirmation = true
                    }
                }) {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Apply Changes")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(Constants.cornerRadius)
                }
                .buttonStyle(.plain)
                .disabled(result.requiresUserConsent)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Actions

    private func analyzeSchedule() {
        isLoading = true

        // Run analysis
        Task { @MainActor in
            let engine = ReshuffleEngine()
            result = engine.analyze(
                items: itemsForDate,
                for: selectedDate
            )
            isLoading = false
        }
    }

    private func applyChanges() {
        guard let result = result else { return }

        Task { @MainActor in
            let repository = SwiftDataScheduleRepository(modelContext: modelContext)
            try? await repository.applyChanges(result.changes)
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
