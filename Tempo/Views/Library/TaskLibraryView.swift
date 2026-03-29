import SwiftUI
import SwiftData

struct TaskLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskDefinition.createdAt) private var allTasks: [TaskDefinition]
    @Query private var allScheduleItems: [ScheduleItem]

    @State private var showingAdd = false
    @State private var editingTask: TaskDefinition?
    @State private var showCompleted = false

    /// Returns the earliest upcoming (or most recent) ScheduleItem linked to this task.
    private func scheduledItem(for task: TaskDefinition) -> ScheduleItem? {
        allScheduleItems
            .filter { $0.taskDefinitionId == task.id }
            .sorted { $0.startTime < $1.startTime }
            .first
    }

    private var pendingTasks: [TaskDefinition] {
        allTasks.filter { !$0.isCompleted }
    }

    private var completedTasks: [TaskDefinition] {
        allTasks.filter { $0.isCompleted }
    }

    var body: some View {
        Group {
            if allTasks.isEmpty {
                emptyState
            } else {
                taskList
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            TaskDefinitionEditView(task: nil)
        }
        .sheet(item: $editingTask) { t in
            TaskDefinitionEditView(task: t)
        }
    }

    private var taskList: some View {
        List {
            if !pendingTasks.isEmpty {
                Section("Pending") {
                    ForEach(pendingTasks) { task in
                        taskRow(task)
                    }
                }
            }

            if !completedTasks.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $showCompleted) {
                        ForEach(completedTasks) { task in
                            taskRow(task)
                        }
                    } label: {
                        Text("Completed (\(completedTasks.count))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.default, value: showCompleted)
    }

    private func taskRow(_ task: TaskDefinition) -> some View {
        let scheduled = scheduledItem(for: task)
        let color = Color(hex: task.colorHex) ?? .blue
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: task.iconName)
                    .foregroundStyle(color)
                    .font(.system(size: 16))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                HStack(spacing: 6) {
                    Text("\(task.durationMinutes)m")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let deadline = task.deadline {
                        deadlineBadge(deadline, isCompleted: task.isCompleted)
                    }
                    if let item = scheduled {
                        scheduledBadge(item, color: color)
                    }
                }
            }

            Spacer()

            Button {
                task.isCompleted.toggle()
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture { editingTask = task }
        .opacity(task.isCompleted ? 0.6 : 1)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                modelContext.delete(task)
            } label: {
                Image(systemName: "trash")
            }
        }
    }

    private func scheduledBadge(_ item: ScheduleItem, color: Color) -> some View {
        let isToday = Calendar.current.isDateInToday(item.scheduledDate)
        let label = isToday
            ? Text(item.startTime, format: .dateTime.hour().minute())
            : Text(item.startTime, format: .dateTime.month(.abbreviated).day().hour().minute())
        return HStack(spacing: 3) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.caption2)
            label
                .font(.caption2)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.1), in: Capsule())
    }

    private func deadlineBadge(_ date: Date, isCompleted: Bool) -> some View {
        let isPast = date < Date() && !isCompleted
        return Text(date, format: .dateTime.month(.abbreviated).day())
            .font(.caption)
            .foregroundStyle(isPast ? .red : .secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isPast ? Color.red.opacity(0.1) : Color(.systemGray6),
                        in: Capsule())
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("No Tasks Yet")
                .font(.headline)
            Text("Add tasks with deadlines and schedule\nthem into your day from the timeline.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Add Task") { showingAdd = true }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func delete(from list: [TaskDefinition], at indexSet: IndexSet) {
        for i in indexSet {
            modelContext.delete(list[i])
        }
    }
}
