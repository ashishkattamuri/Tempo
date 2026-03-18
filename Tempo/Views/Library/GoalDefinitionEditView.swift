import SwiftUI
import SwiftData

/// Create or edit a GoalDefinition in the library.
struct GoalDefinitionEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let goal: GoalDefinition?

    @State private var name: String = ""
    @State private var iconName: String = "star.fill"
    @State private var selectedColor: Color = Color(hex: "#10B981") ?? .green
    @State private var defaultDuration: Int = 30
    @State private var notes: String = ""
    @State private var hasInitialized = false

    private let iconOptions = [
        "star.fill", "trophy.fill", "flag.fill", "target",
        "chart.bar.fill", "arrow.up.forward", "checkmark.seal.fill", "pencil",
        "book.fill", "music.note", "figure.run", "dumbbell.fill",
        "paintbrush.fill", "camera.fill", "mic.fill", "laptopcomputer"
    ]

    private let quickDurations = [15, 30, 45, 60, 90, 120]

    private var isEditing: Bool { goal != nil }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    nameSection
                    iconSection
                    colorSection
                    durationSection
                    notesSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isEditing ? "Edit Goal" : "New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveGoal)
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedColor.opacity(0.2))
                    .frame(width: 48, height: 48)
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundStyle(selectedColor)
            }
            TextField("Goal name", text: $name)
                .font(.title3)
                .fontWeight(.medium)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
    }

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Icon")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(iconOptions, id: \.self) { icon in
                        Button(action: { iconName = icon }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(iconName == icon ? selectedColor.opacity(0.2) : Color(.systemGray5))
                                    .frame(width: 44, height: 44)
                                Image(systemName: icon)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(iconName == icon ? selectedColor : .secondary)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(iconName == icon ? selectedColor : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Color")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Color.goalPresets.indices, id: \.self) { i in
                        let preset = Color.goalPresets[i]
                        Button(action: { selectedColor = preset }) {
                            ZStack {
                                Circle()
                                    .fill(preset)
                                    .frame(width: 36, height: 36)
                                if preset.toHex() == selectedColor.toHex() {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Default Duration")
                    .font(.headline)
                Spacer()
                Text("\(defaultDuration) min")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                ForEach(quickDurations, id: \.self) { d in
                    Button(action: { defaultDuration = d }) {
                        Text(d >= 60 ? "\(d/60)h" : "\(d)")
                            .font(.subheadline)
                            .fontWeight(defaultDuration == d ? .semibold : .regular)
                            .foregroundStyle(defaultDuration == d ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10)
                                .fill(defaultDuration == d ? selectedColor : Color(.systemGray5)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes (optional)")
                .font(.headline)
            TextEditor(text: $notes)
                .padding(8)
                .frame(minHeight: 80)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(12)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
    }

    // MARK: - Actions

    private func loadExisting() {
        guard !hasInitialized, let g = goal else {
            hasInitialized = true
            return
        }
        hasInitialized = true
        name = g.name
        iconName = g.iconName
        selectedColor = Color(hex: g.colorHex) ?? .green
        defaultDuration = g.defaultDurationMinutes
        notes = g.notes ?? ""
    }

    private func saveGoal() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let existing = goal {
            existing.name = trimmed
            existing.iconName = iconName
            existing.colorHex = selectedColor.toHex()
            existing.defaultDurationMinutes = defaultDuration
            existing.notes = notes.isEmpty ? nil : notes
        } else {
            let g = GoalDefinition(
                name: trimmed,
                iconName: iconName,
                colorHex: selectedColor.toHex(),
                defaultDurationMinutes: defaultDuration,
                notes: notes.isEmpty ? nil : notes
            )
            modelContext.insert(g)
        }
        dismiss()
    }
}

#Preview {
    GoalDefinitionEditView(goal: nil)
        .modelContainer(for: GoalDefinition.self, inMemory: true)
}
