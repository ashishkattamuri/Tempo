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
                    .foregroundStyle(category.color)
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
                .tint(category.color)

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
                .foregroundStyle(isSelected ? .white : .primary)
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
                        .foregroundStyle(.primary)

                    Spacer()

                    // Selected category badge
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(category.color.opacity(0.2))
                                .frame(width: 28, height: 28)

                            Image(systemName: category.iconName)
                                .font(.system(size: 12))
                                .foregroundStyle(category.color)
                        }

                        Text(category.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
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
.foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isValid ? category.color : Color(.systemGray4))
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
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        // Combine scheduledDate with startTime to ensure correct date component
        let combinedStartTime = combineDateAndTime(date: scheduledDate, time: startTime)

        if let existingItem = item {
            existingItem.title = trimmedTitle
            existingItem.category = category
            existingItem.startTime = combinedStartTime
            existingItem.durationMinutes = durationMinutes
            existingItem.minimumDurationMinutes = category == .identityHabit ? minimumDurationMinutes : nil
            existingItem.notes = notes.isEmpty ? nil : notes
            existingItem.scheduledDate = scheduledDate
            existingItem.isEveningTask = isEveningTask
            existingItem.isGentleTask = isGentleTask
            existingItem.isRecurring = isRecurring
            existingItem.frequency = frequency
            existingItem.timesPerWeek = frequency == .weekly ? recurrenceDays.count : nil
            existingItem.recurrenceDays = recurrenceDays
            existingItem.recurrenceEndDate = recurrenceEndDate
            existingItem.touch()

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

            // Generate recurring instances if needed
            if isRecurring && !recurrenceDays.isEmpty {
                generateRecurringInstances(for: newItem)
            }

            onSave(newItem)
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
                                .foregroundStyle(category.color)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.displayName)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)

                            Text(category.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if selection == category {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(category.color)
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
