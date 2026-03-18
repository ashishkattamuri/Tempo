import SwiftUI
import SwiftData

/// List of all GoalDefinitions with create/edit/delete.
struct GoalLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GoalDefinition.createdAt) private var goals: [GoalDefinition]

    @State private var showingCreate = false
    @State private var editingGoal: GoalDefinition? = nil

    var body: some View {
        Group {
            if goals.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(goals) { goal in
                        goalRow(goal)
                            .contentShape(Rectangle())
                            .onTapGesture { editingGoal = goal }
                    }
                    .onDelete(perform: deleteGoals)
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
            GoalDefinitionEditView(goal: nil)
        }
        .sheet(item: $editingGoal) { goal in
            GoalDefinitionEditView(goal: goal)
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.circle")
                .font(.system(size: 56))
                .foregroundStyle(.green.opacity(0.5))
            Text("No Goals Yet")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Save goals here so you can quickly schedule them each day.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(action: { showingCreate = true }) {
                Label("Add Goal", systemImage: "plus")
                    .fontWeight(.medium)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.green.opacity(0.12))
                    .foregroundStyle(.green)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func goalRow(_ goal: GoalDefinition) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill((Color(hex: goal.colorHex) ?? .green).opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: goal.iconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(hex: goal.colorHex) ?? .green)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(goal.name)
                    .font(.body)
                    .fontWeight(.medium)
                Text("\(goal.defaultDurationMinutes) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func deleteGoals(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(goals[index])
        }
    }
}

extension GoalDefinition: Identifiable {}

#Preview {
    NavigationStack {
        GoalLibraryView()
            .navigationTitle("Goals")
    }
    .modelContainer(for: GoalDefinition.self, inMemory: true)
}
