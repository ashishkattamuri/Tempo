import SwiftUI
import SwiftData

/// View for creating or editing a task - Structured-inspired design.
struct TaskEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let item: ScheduleItem?
    let selectedDate: Date
    var defaultStartTime: Date? = nil
    let onSave: (ScheduleItem) -> Void
    let onCancel: () -> Void

    @State private var title: String = ""
    @State private var category: TaskCategory = .flexibleTask
    @State private var startTime: Date = Date()
    @State private var durationMinutes: Int = 30
    @State private var minimumDurationMinutes: Int? = nil
    @State private var notes: String = ""
    @State private var isEveningTask: Bool = false
    @State private var isGentleTask: Bool = false
    @State private var selectedColor: Color = .blue

    @State private var showingDeleteConfirmation = false
    @State private var showingDatePicker = false
    @State private var scheduledDate: Date = Date()
    @State private var hasInitialized = false
    @State private var showingRecurringEditScope = false

    // Recurrence state
    @State private var isRecurring: Bool = false
    @State private var recurrenceDays: [Int] = []
    @State private var recurrenceEndDate: Date? = nil

    /// Computed frequency based on selected days (7 days = daily, otherwise weekly)
    private var frequency: RecurrenceFrequency {
        recurrenceDays.count == 7 ? .daily : .weekly
    }

    private var isEditing: Bool { item != nil }
    private var isEditingInstance: Bool { item?.isRecurrenceInstance ?? false }
    private var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    // Quick duration options
    private let quickDurations = [5, 15, 30, 45, 60, 120]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Task name with icon
                    taskNameSection

                    // Category (moved up for quick access)
                    categorySection

                    // When (time picker)
                    whenSection

                    // How long (duration)
                    durationSection

                    // Recurrence (available for all task types except when editing an instance)
                    if !isEditingInstance {
                        recurrenceSection
                    }

                    // Identity habit settings
                    if category == .identityHabit {
                        identityHabitSection
                    }

                    // Notes
                    notesSection

                    // Delete button (for existing items)
                    if isEditing {
                        deleteSection
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .safeAreaInset(edge: .bottom) {
                saveButton
            }
            .onAppear(perform: loadExistingItem)
            .onChange(of: category) { _, newValue in
                selectedColor = newValue.color
            }
            .confirmationDialog(
                "Delete this task?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive, action: deleteItem)
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showingRecurringEditScope) {
                RecurringEditScopeSheet(
                    onThisOnly: {
                        showingRecurringEditScope = false
                        performSave(scope: .thisOnly)
                    },
                    onThisAndFuture: {
                        showingRecurringEditScope = false
                        performSave(scope: .thisAndFuture)
                    },
                    onCancel: {
                        showingRecurringEditScope = false
                    }
                )
                .presentationDetents([.height(260)])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Sections

    private var taskNameSection: some View {
        HStack(spacing: 12) {
            // Category icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(category.color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: category.iconName)
                    .font(.title2)
                    .foregroundColor(category.color)
            }

            TextField("Task name", text: $title)
                .font(.title3)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private var whenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("When?")
                    .font(.headline)
                Spacer()
            }

            // Date picker - inline graphical style
            VStack(spacing: 8) {
                DatePicker(
                    "Date",
                    selection: $scheduledDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)

                Divider()

                // Time picker
                DatePicker(
                    "Time",
                    selection: $startTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("How long?")
                    .font(.headline)
                Spacer()
                if !quickDurations.contains(durationMinutes) {
                    Text("\(durationMinutes) min")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Quick duration buttons
            HStack(spacing: 8) {
                ForEach(quickDurations, id: \.self) { duration in
                    durationButton(duration)
                }
            }

            // Custom duration slider
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { Double(durationMinutes) },
                        set: { durationMinutes = Int($0) }
                    ),
                    in: 5...480,
                    step: 5
                )
                .tint(category.color)

                HStack {
                    Text("5m")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("8h")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private func durationButton(_ duration: Int) -> some View {
        let isSelected = durationMinutes == duration
        let label = duration >= 60 ? "\(duration / 60)h" : "\(duration)"

        return Button(action: { durationMinutes = duration }) {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? category.color : Color(.systemGray5))
                )
        }
        .buttonStyle(.plain)
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink {
                CategoryPickerScreen(selection: $category)
            } label: {
                HStack(spacing: 12) {
                    Text("Category")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    // Selected category badge
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(category.color.opacity(0.2))
                                .frame(width: 28, height: 28)

                            Image(systemName: category.iconName)
                                .font(.system(size: 12))
                                .foregroundColor(category.color)
                        }

                        Text(category.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private var recurrenceSection: some View {
        RecurrencePicker(
            isRecurring: $isRecurring,
            selectedDays: $recurrenceDays,
            endDate: $recurrenceEndDate
        )
    }

    private var identityHabitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Identity Habit Settings")
                .font(.headline)

            Toggle("Can be compressed on hard days", isOn: Binding(
                get: { minimumDurationMinutes != nil },
                set: { enabled in
                    if enabled {
                        minimumDurationMinutes = min(durationMinutes, Constants.defaultIdentityHabitMinimumMinutes)
                    } else {
                        minimumDurationMinutes = nil
                    }
                }
            ))

            if minimumDurationMinutes != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Minimum duration: \(minimumDurationMinutes ?? 10) min")
                        .font(.subheadline)

                    Slider(
                        value: Binding(
                            get: { Double(minimumDurationMinutes ?? 10) },
                            set: { minimumDurationMinutes = Int($0) }
                        ),
                        in: 5...Double(durationMinutes),
                        step: 5
                    )
                    .tint(.purple)
                }

                Text("On hard days, this habit can be compressed to the minimum while still counting as \"showing up\"")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes (optional)")
                .font(.headline)

            TextEditor(text: $notes)
                .frame(minHeight: 80)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private var deleteSection: some View {
        Button(action: { showingDeleteConfirmation = true }) {
            HStack {
                Image(systemName: "trash")
                Text("Delete Task")
            }
            .font(.body)
            .fontWeight(.medium)
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.red.opacity(0.1))
            .cornerRadius(12)
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text(isEditing ? "Update Task" : "Add Task")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isValid ? category.color : Color.gray)
                )
        }
        .disabled(!isValid)
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Actions

    private func loadExistingItem() {
        guard !hasInitialized else { return }
        hasInitialized = true

        // Initialize scheduled date
        scheduledDate = selectedDate

        if let item = item {
            title = item.title
            category = item.category
            startTime = item.startTime
            durationMinutes = item.durationMinutes
            minimumDurationMinutes = item.minimumDurationMinutes
            notes = item.notes ?? ""
            isEveningTask = item.isEveningTask
            isGentleTask = item.isGentleTask
            selectedColor = item.category.color
            scheduledDate = item.scheduledDate
            isRecurring = item.isRecurring
            recurrenceDays = item.recurrenceDays
            recurrenceEndDate = item.recurrenceEndDate
        } else if let defaultTime = defaultStartTime {
            startTime = defaultTime
            isEveningTask = defaultTime.isEvening
        }
    }

    private func save() {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        // If editing a recurring item, ask user for scope before saving
        if let existingItem = item, existingItem.isRecurring || existingItem.isRecurrenceInstance {
            showingRecurringEditScope = true
            return
        }

        performSave(scope: .thisOnly)
    }

    private func performSave(scope: RecurringEditScope) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        let combinedStartTime = combineDateAndTime(date: scheduledDate, time: startTime)

        if let existingItem = item {
            applyChanges(to: existingItem, newStartTime: combinedStartTime, newScheduledDate: scheduledDate)

            if scope == .thisAndFuture {
                applyEditsToFutureInstances(from: existingItem, newStartTime: combinedStartTime)
            }

            onSave(existingItem)
        } else {
            let newItem = ScheduleItem(
                title: trimmedTitle,
                category: category,
                startTime: combinedStartTime,
                durationMinutes: durationMinutes,
                minimumDurationMinutes: category == .identityHabit ? minimumDurationMinutes : nil,
                notes: notes.isEmpty ? nil : notes,
                scheduledDate: scheduledDate,
                isEveningTask: isEveningTask,
                isGentleTask: isGentleTask,
                isRecurring: isRecurring,
                frequency: frequency,
                timesPerWeek: frequency == .weekly ? recurrenceDays.count : nil,
                recurrenceDays: recurrenceDays,
                recurrenceEndDate: recurrenceEndDate
            )

            modelContext.insert(newItem)

            if isRecurring && !recurrenceDays.isEmpty {
                generateRecurringInstances(for: newItem)
            }

            onSave(newItem)
        }
    }

    /// Applies form values to a single item
    private func applyChanges(to target: ScheduleItem, newStartTime: Date, newScheduledDate: Date) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        target.title = trimmedTitle
        target.category = category
        target.startTime = newStartTime
        target.durationMinutes = durationMinutes
        target.minimumDurationMinutes = category == .identityHabit ? minimumDurationMinutes : nil
        target.notes = notes.isEmpty ? nil : notes
        target.scheduledDate = newScheduledDate
        target.isEveningTask = isEveningTask
        target.isGentleTask = isGentleTask
        target.isRecurring = isRecurring
        target.frequency = frequency
        target.timesPerWeek = frequency == .weekly ? recurrenceDays.count : nil
        target.recurrenceDays = recurrenceDays
        target.recurrenceEndDate = recurrenceEndDate
        target.touch()
    }

    /// Updates all future instances of the same recurring task
    private func applyEditsToFutureInstances(from editedItem: ScheduleItem, newStartTime: Date) {
        let parentId = editedItem.isRecurrenceInstance ? editedItem.parentTaskId : editedItem.id
        guard let parentId else { return }

        let editedDate = editedItem.scheduledDate
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: newStartTime)
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)

        let descriptor = FetchDescriptor<ScheduleItem>()
        guard let allItems = try? modelContext.fetch(descriptor) else { return }

        let futureItems = allItems.filter { candidate in
            guard candidate.id != editedItem.id else { return false }
            guard candidate.scheduledDate >= editedDate else { return false }
            if candidate.isRecurrenceInstance {
                return candidate.parentTaskId == parentId
            } else {
                return candidate.id == parentId
            }
        }

        for future in futureItems {
            future.title = trimmedTitle
            future.category = category
            future.durationMinutes = durationMinutes
            future.minimumDurationMinutes = category == .identityHabit ? minimumDurationMinutes : nil
            future.notes = notes.isEmpty ? nil : notes
            future.isEveningTask = isEveningTask
            future.isGentleTask = isGentleTask

            // Preserve each instance's own date, only update the time
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: future.scheduledDate)
            comps.hour = timeComponents.hour
            comps.minute = timeComponents.minute
            if let newStart = Calendar.current.date(from: comps) {
                future.startTime = newStart
            }

            future.touch()
        }
    }

    /// Generates recurring task instances for the next few weeks
    private func generateRecurringInstances(for template: ScheduleItem) {
        let calendar = Calendar.current
        let weeksToGenerate = 4

        // Start from tomorrow
        guard let startDate = calendar.date(byAdding: .day, value: 1, to: template.scheduledDate) else { return }
        let endDate = recurrenceEndDate ?? calendar.date(byAdding: .weekOfYear, value: weeksToGenerate, to: startDate)!

        var currentDate = startDate
        while currentDate <= endDate {
            let weekday = calendar.component(.weekday, from: currentDate) - 1 // Convert to 0-indexed
            if recurrenceDays.contains(weekday) {
                let instance = template.createRecurrenceInstance(for: currentDate)
                modelContext.insert(instance)
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
    }

    /// Combines the date component from one Date with the time component from another
    private func combineDateAndTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        combined.second = timeComponents.second

        return calendar.date(from: combined) ?? date
    }

    private func deleteItem() {
        guard let item = item else { return }
        modelContext.delete(item)
        dismiss()
    }
}

// MARK: - Recurring Edit Scope

private enum RecurringEditScope {
    case thisOnly
    case thisAndFuture
}

/// Sheet asking the user whether edits should apply to this event only or all future events
struct RecurringEditScopeSheet: View {
    let onThisOnly: () -> Void
    let onThisAndFuture: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Edit Recurring Task")
                    .font(.headline)
                Text("Apply changes to just this event or all future events?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            VStack(spacing: 12) {
                Button(action: onThisOnly) {
                    HStack {
                        Image(systemName: "calendar")
                        Text("This event only")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Button(action: onThisAndFuture) {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                        Text("This and all future events")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundColor(.accentColor)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Button(action: onCancel) {
                    Text("Cancel")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}

/// Full-screen category picker (kept for navigation link compatibility)
struct CategoryPickerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: TaskCategory

    var body: some View {
        List {
            ForEach(TaskCategory.allCases) { category in
                Button(action: {
                    selection = category
                    dismiss()
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(category.color.opacity(0.2))
                                .frame(width: 44, height: 44)

                            Image(systemName: category.iconName)
                                .font(.title3)
                                .foregroundColor(category.color)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.displayName)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)

                            Text(category.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if selection == category {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(category.color)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Category")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Previews

#Preview("New Task") {
    TaskEditView(
        item: nil,
        selectedDate: Date(),
        onSave: { _ in },
        onCancel: {}
    )
    .modelContainer(for: ScheduleItem.self, inMemory: true)
}

#Preview("Edit Task") {
    TaskEditView(
        item: ScheduleItem(
            title: "Morning Meditation",
            category: .identityHabit,
            startTime: Date().withTime(hour: 7),
            durationMinutes: 30,
            minimumDurationMinutes: 10
        ),
        selectedDate: Date(),
        onSave: { _ in },
        onCancel: {}
    )
    .modelContainer(for: ScheduleItem.self, inMemory: true)
}
