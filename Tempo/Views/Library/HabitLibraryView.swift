import SwiftUI
import SwiftData

/// List of all HabitDefinitions with create/edit/delete.
struct HabitLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HabitDefinition.createdAt) private var habits: [HabitDefinition]

    @State private var showingCreate = false
    @State private var editingHabit: HabitDefinition? = nil

    var body: some View {
        Group {
            if habits.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(habits) { habit in
                        habitRow(habit)
                            .contentShape(Rectangle())
                            .onTapGesture { editingHabit = habit }
                    }
                    .onDelete(perform: deleteHabits)
                }
                .listStyle(.insetGrouped)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingCreate = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreate) {
            HabitDefinitionEditView(habit: nil)
        }
        .sheet(item: $editingHabit) { habit in
            HabitDefinitionEditView(habit: habit)
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.circle")
                .font(.system(size: 56))
                .foregroundStyle(.purple.opacity(0.5))
            Text("No Habits Yet")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Save habits here so you can quickly schedule them each day.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(action: { showingCreate = true }) {
                Label("Add Habit", systemImage: "plus")
                    .fontWeight(.medium)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.purple.opacity(0.12))
                    .foregroundStyle(.purple)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func habitRow(_ habit: HabitDefinition) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill((Color(hex: habit.colorHex) ?? .purple).opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: habit.iconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(hex: habit.colorHex) ?? .purple)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(habit.name)
                    .font(.body)
                    .fontWeight(.medium)
                HStack(spacing: 4) {
                    Text("\(habit.defaultDurationMinutes) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("min \(habit.minimumDurationMinutes) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func deleteHabits(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(habits[index])
        }
    }
}

extension HabitDefinition: Identifiable {}

#Preview {
    NavigationStack {
        HabitLibraryView()
            .navigationTitle("Habits")
    }
    .modelContainer(for: HabitDefinition.self, inMemory: true)
}
