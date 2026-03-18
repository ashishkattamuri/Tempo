import SwiftUI
import SwiftData

/// View for creating or editing a task - Structured-inspired design.
struct TaskEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var focusBlockManager: FocusBlockManager
    @Query(sort: \HabitDefinition.createdAt) private var habitDefinitions: [HabitDefinition]
    @Query(sort: \GoalDefinition.createdAt) private var goalDefinitions: [GoalDefinition]

    let item: ScheduleItem?
    let selectedDate: Date
    var defaultStartTime: Date? = nil
    let onSave: (ScheduleItem) -> Void
    let onCancel: () -> Void

    @State private var title: String = ""
    @State private var selectedType: ScheduleItemType = .task
    @State private var startTime: Date = Date()
    @State private var durationMinutes: Int = 30
    @State private var minimumDurationMinutes: Int? = nil
    @State private var notes: String = ""
    @State private var isEveningTask: Bool = false
    @State private var isGentleTask: Bool = false

    @State private var showingDeleteConfirmation = false
    @State private var showingDatePicker = false
    @State private var scheduledDate: Date = Date()
    @State private var hasInitialized = false
    @State private var showingRecurringEditScope = false

    // Library selection
    @State private var selectedHabitDef: HabitDefinition? = nil
    @State private var selectedGoalDef: GoalDefinition? = nil
    @State private var showingHabitPicker = false
    @State private var showingGoalPicker = false

    // Recurrence state
    @State private var isRecurring: Bool = false
    @State private var recurrenceDays: [Int] = []
    @State private var recurrenceEndDate: Date? = nil

    // Focus Block state
    @State private var focusGroupId: UUID? = nil

    private var category: TaskCategory { selectedType.taskCategory }

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

                    // Type picker: Event | Task | Habit | Goal
                    typePickerSection

                    // Optional library picker row (Habit or Goal only)
                    if selectedType == .habit || selectedType == .goal {
                        libraryPickerRow
                    }

                    // When (time picker)
                    whenSection

                    // How long (duration)
                    durationSection

                    // Recurrence (available for all task types except when editing an instance)
                    if !isEditingInstance {
                        recurrenceSection
                    }

                    // Habit compression settings (habits only)
                    if selectedType == .habit {
                        identityHabitSection
                    }

                    // Focus Block
                    focusBlockSection

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
            .sheet(isPresented: $showingHabitPicker) {
                HabitPickerSheet(
                    habits: habitDefinitions,
                    onSelect: { habit in
                        selectedHabitDef = habit
                        title = habit.name
                        durationMinutes = habit.defaultDurationMinutes
                        minimumDurationMinutes = habit.minimumDurationMinutes
                        showingHabitPicker = false
                    },
                    onCancel: { showingHabitPicker = false }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingGoalPicker) {
                GoalPickerSheet(
                    goals: goalDefinitions,
                    onSelect: { goal in
                        selectedGoalDef = goal
                        title = goal.name
                        durationMinutes = goal.defaultDurationMinutes
                        showingGoalPicker = false
                    },
                    onCancel: { showingGoalPicker = false }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Sections

    private var taskNameSection: some View {
        HStack(spacing: 12) {
            // Type icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedType.color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: selectedType.iconName)
                    .font(.title2)
                    .foregroundStyle(selectedType.color)
            }

            TextField("Task name", text: $title)
                .font(.title3)
                .fontWeight(.medium)
        }
        .padding()
       .background(
    RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(Color(.secondarySystemBackground))
)
.overlay(
    RoundedRectangle(cornerRadius: 16)
        .stroke(Color(.separator), lineWidth: 0.5)
)
    }

  private var whenSection: some View {

    VStack(alignment: .leading, spacing: 12) {

        Text("When?")
            .font(.headline)

        VStack(spacing: 12) {

            HStack {
                DatePicker(
                    "Date",
                    selection: $scheduledDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(12)


            HStack {
                DatePicker(
                    "Time",
                    selection: $startTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(12)

        }

    }
    .padding()
    .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.secondarySystemBackground))
    )
    .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Color(.separator), lineWidth: 0.5)
    )

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
                        .foregroundStyle(.secondary)
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
                .tint(selectedType.color)

                HStack {
                    Text("5m")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("8h")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
       .background(
    RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(Color(.secondarySystemBackground))
)
.overlay(
    RoundedRectangle(cornerRadius: 16)
        .stroke(Color(.separator), lineWidth: 0.5)
)
    }

    private func durationButton(_ duration: Int) -> some View {
        let isSelected = durationMinutes == duration
        let label = duration >= 60 ? "\(duration / 60)h" : "\(duration)"

        return Button(action: { durationMinutes = duration }) {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? selectedType.color : Color(.systemGray5))
                )
        }
        .buttonStyle(.plain)
    }

    private var typePickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What kind of block?")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(ScheduleItemType.allCases) { type in
                    Button(action: {
                        selectedType = type
                        // Clear library selections when switching type
                        if type != .habit { selectedHabitDef = nil }
                        if type != .goal  { selectedGoalDef = nil }
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: type.iconName)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(selectedType == type ? .white : type.color)
                            Text(type.displayName)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(selectedType == type ? .white : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedType == type ? type.color : Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedType == type ? type.color : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var libraryPickerRow: some View {
        if selectedType == .habit {
            Button(action: { showingHabitPicker = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "books.vertical.fill")
                        .foregroundStyle(.purple)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use from Library")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        if let habit = selectedHabitDef {
                            Text(habit.name + " · \(habit.defaultDurationMinutes) min")
                                .font(.caption)
                                .foregroundStyle(.purple)
                        } else {
                            Text("Optionally pick a saved habit")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if selectedHabitDef != nil {
                        Button(action: {
                            selectedHabitDef = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(selectedHabitDef != nil ? Color.purple.opacity(0.4) : Color(.separator), lineWidth: selectedHabitDef != nil ? 1.5 : 0.5)
                )
            }
            .buttonStyle(.plain)
        } else if selectedType == .goal {
            Button(action: { showingGoalPicker = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "books.vertical.fill")
                        .foregroundStyle(.green)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use from Library")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        if let goal = selectedGoalDef {
                            Text(goal.name + " · \(goal.defaultDurationMinutes) min")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Text("Optionally pick a saved goal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if selectedGoalDef != nil {
                        Button(action: {
                            selectedGoalDef = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(selectedGoalDef != nil ? Color.green.opacity(0.4) : Color(.separator), lineWidth: selectedGoalDef != nil ? 1.5 : 0.5)
                )
            }
            .buttonStyle(.plain)
        }
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
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
       .background(
    RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(Color(.secondarySystemBackground))
)
.overlay(
    RoundedRectangle(cornerRadius: 16)
        .stroke(Color(.separator), lineWidth: 0.5)
)
    }

    private var focusBlockSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if focusBlockManager.groups.isEmpty {
                // No groups yet — show disabled toggle with clear call to action
                HStack(spacing: 10) {
                    Image(systemName: "moon.circle.fill")
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Focus Block")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("No Focus Groups yet. Go to Settings → Focus Block to create one.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Toggle(isOn: Binding(
                    get: { focusGroupId != nil },
                    set: { enabled in
                        if !enabled { focusGroupId = nil }
                        else { focusGroupId = focusBlockManager.groups.first?.id }
                    }
                )) {
                    HStack(spacing: 10) {
                        Image(systemName: "moon.circle.fill")
                            .foregroundColor(.indigo)
                        Text("Focus Block")
                            .font(.headline)
                    }
                }
                .tint(.indigo)

                if focusGroupId != nil {
                    Picker("Focus Group", selection: Binding(
                        get: { focusGroupId ?? focusBlockManager.groups.first?.id },
                        set: { focusGroupId = $0 }
                    )) {
                        ForEach(focusBlockManager.groups) { group in
                            Label(group.name, systemImage: group.symbol)
                                .tag(Optional(group.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
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
    .padding(8)
    .frame(minHeight: 100)
    .background(Color(.tertiarySystemBackground))
    .cornerRadius(12)
        }
        .padding()
       .background(
    RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(Color(.secondarySystemBackground))
)
.overlay(
    RoundedRectangle(cornerRadius: 16)
        .stroke(Color(.separator), lineWidth: 0.5)
)
    }

    private var deleteSection: some View {
        Button(action: { showingDeleteConfirmation = true }) {
            HStack {
                Image(systemName: "trash")
                Text("Delete Task")
            }
            .font(.body)
            .fontWeight(.medium)
            .foregroundStyle(.red)
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
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            isValid
            ? Color.accentColor
            : Color(.systemGray4)
        )
        .foregroundColor(.white)
        .cornerRadius(14)

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
            selectedType = ScheduleItemType(from: item.category)
            startTime = item.startTime
            durationMinutes = item.durationMinutes
            minimumDurationMinutes = item.minimumDurationMinutes
            notes = item.notes ?? ""
            isEveningTask = item.isEveningTask
            isGentleTask = item.isGentleTask
            scheduledDate = item.scheduledDate
            isRecurring = item.isRecurring
            recurrenceDays = item.recurrenceDays
            recurrenceEndDate = item.recurrenceEndDate
            if let raw = item.focusGroupIdRaw {
                focusGroupId = UUID(uuidString: raw)
            }
            // Restore library selection references
            if let habId = item.habitDefinitionId {
                selectedHabitDef = habitDefinitions.first(where: { $0.id == habId })
            }
            if let goalId = item.goalDefinitionId {
                selectedGoalDef = goalDefinitions.first(where: { $0.id == goalId })
            }
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

            newItem.focusGroupIdRaw = focusGroupId?.uuidString
            newItem.habitDefinitionId = selectedHabitDef?.id
            newItem.goalDefinitionId = selectedGoalDef?.id
            modelContext.insert(newItem)

            if isRecurring && !recurrenceDays.isEmpty {
                generateRecurringInstances(for: newItem)
            }

            if newItem.isFocusBlock {
                focusBlockManager.scheduleBlocking(for: newItem)
                focusBlockManager.scheduleNotifications(for: newItem)
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

        // Update definition IDs
        target.habitDefinitionId = selectedHabitDef?.id
        target.goalDefinitionId = selectedGoalDef?.id

        // Handle focus block changes
        let previousGroupId = target.focusGroupIdRaw
        target.focusGroupIdRaw = focusGroupId?.uuidString
        if previousGroupId != nil {
            focusBlockManager.cancelBlocking(for: target)
            focusBlockManager.cancelNotifications(for: target)
        }
        if target.isFocusBlock {
            focusBlockManager.scheduleBlocking(for: target)
            focusBlockManager.scheduleNotifications(for: target)
        }

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

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(TaskCategory.allCases) { category in
                    Button(action: {
                        selection = category
                        dismiss()
                    }) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(category.color.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: category.iconName)
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundStyle(category.color)
                                }
                                Spacer()
                                if selection == category {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(category.color)
                                }
                            }

                            Text(category.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(selection == category ? category.color : .primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Text(category.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(selection == category
                                      ? category.color.opacity(0.1)
                                      : Color(.secondarySystemGroupedBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(selection == category ? category.color : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Category")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Library Picker Sheets

struct HabitPickerSheet: View {
    let habits: [HabitDefinition]
    let onSelect: (HabitDefinition) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if habits.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "heart.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(.purple.opacity(0.5))
                        Text("No habits in library yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Add habits in the Library tab first.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(habits) { habit in
                        Button(action: { onSelect(habit) }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill((Color(hex: habit.colorHex) ?? .purple).opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: habit.iconName)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(Color(hex: habit.colorHex) ?? .purple)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(habit.name)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    Text("\(habit.defaultDurationMinutes) min · min \(habit.minimumDurationMinutes) min")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Pick a Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}

struct GoalPickerSheet: View {
    let goals: [GoalDefinition]
    let onSelect: (GoalDefinition) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if goals.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "star.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(.green.opacity(0.5))
                        Text("No goals in library yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Add goals in the Library tab first.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(goals) { goal in
                        Button(action: { onSelect(goal) }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill((Color(hex: goal.colorHex) ?? .green).opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: goal.iconName)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(Color(hex: goal.colorHex) ?? .green)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(goal.name)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    Text("\(goal.defaultDurationMinutes) min")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Pick a Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
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
    .modelContainer(for: [ScheduleItem.self, HabitDefinition.self, GoalDefinition.self], inMemory: true)
    .environmentObject(FocusBlockManager())
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
    .modelContainer(for: [ScheduleItem.self, HabitDefinition.self, GoalDefinition.self], inMemory: true)
    .environmentObject(FocusBlockManager())
}
