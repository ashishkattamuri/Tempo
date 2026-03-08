import SwiftUI
import SwiftData

/// View for managing compensation debt - tasks that were deferred and need makeup sessions.
struct CompensationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var compensationTracker: CompensationTracker

    @Query private var allItems: [ScheduleItem]
    @State private var selectedRecord: CompensationRecord?
    @State private var showingSlotPicker = false
    @State private var suggestedSlots: [Date] = []

    var body: some View {
        NavigationStack {
            Group {
                if compensationTracker.pendingCompensations.isEmpty {
                    emptyState
                } else {
                    compensationList
                }
            }
            .navigationTitle("Makeup Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingSlotPicker) {
                if let record = selectedRecord {
                    SlotPickerSheet(
                        record: record,
                        suggestedSlots: suggestedSlots,
                        onSelect: { date in
                            scheduleCompensation(for: record, at: date)
                            showingSlotPicker = false
                            selectedRecord = nil
                        },
                        onDismiss: {
                            showingSlotPicker = false
                            selectedRecord = nil
                        }
                    )
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
             .foregroundStyle(.green)

            Text("All Caught Up!")
                .font(.title2)
                .fontWeight(.semibold)

            Text("You have no pending makeup sessions.\nKeep up the great work!")
                .font(.body)
               .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Compensation List

    private var compensationList: some View {
        List {
            // Summary Section
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Time to make up")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(compensationTracker.formattedPendingTime)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Tasks")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(compensationTracker.pendingCompensations.count)")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                }
                .padding(.vertical, 8)
            }

            // Pending Compensations
            Section("Pending Makeup") {
                ForEach(compensationTracker.pendingCompensations) { record in
                    CompensationRowView(
                        record: record,
                        onSchedule: {
                            prepareSlotPicker(for: record)
                        },
                        onDismiss: {
                            compensationTracker.dismissCompensation(record)
                        }
                    )
                }
            }

            // Weekend Availability
            Section("Weekend Availability") {
                let weekendMinutes = TimeCalculations.weekendFreeMinutes(
                    startingFrom: Date(),
                    existingItems: Array(allItems)
                )

                HStack {
                    Image(systemName: "calendar.badge.clock")
                  .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Free time this weekend")
                            .font(.subheadline)
                        Text(formatMinutes(weekendMinutes))
                            .font(.headline)
                           .foregroundStyle(.blue)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func prepareSlotPicker(for record: CompensationRecord) {
        selectedRecord = record
        suggestedSlots = compensationTracker.findCompensationSlots(
            for: record,
            in: Array(allItems)
        )
        showingSlotPicker = true
    }

    private func scheduleCompensation(for record: CompensationRecord, at date: Date) {
        let compensationTask = compensationTracker.scheduleCompensation(for: record, at: date)
        modelContext.insert(compensationTask)

        compensationTracker.markCompensated(record, minutes: record.remainingMinutes, date: date)
    }

    // MARK: - Helpers

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins > 0 {
                return "\(hours)h \(mins)m"
            } else {
                return "\(hours) hours"
            }
        } else {
            return "\(minutes) minutes"
        }
    }
}

// MARK: - Compensation Row View

struct CompensationRowView: View {
    let record: CompensationRecord
    let onSchedule: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Category indicator
                Circle()
                    .fill(record.category.color)
                    .frame(width: 10, height: 10)

                Text(record.taskTitle)
                    .font(.headline)

                Spacer()

                Text("\(record.remainingMinutes) min")
                    .font(.subheadline)
                   .foregroundStyle(.secondary)
            }

            HStack {
                Text(record.reasonDescription)
                    .font(.caption)
                 .foregroundStyle(.secondary)

                Text("on \(formattedDate)")
                    .font(.caption)
                   .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button(action: onSchedule) {
                    Label("Schedule Makeup", systemImage: "calendar.badge.plus")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .tint(record.category.color)

                Button(action: onDismiss) {
                    Text("Skip")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: record.originalDate)
    }
}

// MARK: - Slot Picker Sheet

struct SlotPickerSheet: View {
    let record: CompensationRecord
    let suggestedSlots: [Date]
    let onSelect: (Date) -> Void
    let onDismiss: () -> Void

    @State private var customDate = Date()
    @State private var showingCustomPicker = false

    var body: some View {
        NavigationStack {
            List {
                // Task Info
                Section {
                    HStack {
                        Circle()
                            .fill(record.category.color)
                            .frame(width: 12, height: 12)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.taskTitle)
                                .font(.headline)
                            Text("\(record.remainingMinutes) minutes needed")
                                .font(.caption)
                              .foregroundStyle(.secondary)
                        }
                    }
                }

                // Suggested Slots
                if !suggestedSlots.isEmpty {
                    Section("Suggested Times") {
                        ForEach(suggestedSlots, id: \.self) { slot in
                            Button(action: { onSelect(slot) }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(formatDate(slot))
                                            .font(.subheadline)
                                        Text(formatTime(slot))
                                            .font(.headline)
                                    }

                                    Spacer()

                                    if TimeCalculations.isWeekend(slot) {
                                        Text("Weekend")
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.1))
                                         .foregroundStyle(.blue)
                                            .cornerRadius(6)
                                    }

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                     .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Custom Time
                Section("Or Choose Custom Time") {
                    DatePicker(
                        "Date & Time",
                        selection: $customDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    Button("Schedule at Custom Time") {
                        onSelect(customDate)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Schedule Makeup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

#Preview {
    CompensationView(compensationTracker: CompensationTracker())
        .modelContainer(for: ScheduleItem.self, inMemory: true)
}
