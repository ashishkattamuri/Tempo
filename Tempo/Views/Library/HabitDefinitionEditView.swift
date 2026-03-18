import SwiftUI
import SwiftData

/// Create or edit a HabitDefinition in the library.
struct HabitDefinitionEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let habit: HabitDefinition?

    @State private var name: String = ""
    @State private var iconName: String = "heart.fill"
    @State private var selectedColor: Color = Color(hex: "#8B5CF6") ?? .purple
    @State private var defaultDuration: Int = 30
    @State private var minimumDuration: Int = 10
    @State private var hasPreferredTime: Bool = false
    @State private var preferredHour: Int = 7
    @State private var notes: String = ""
    @State private var hasInitialized = false

    private let iconOptions = [
        "heart.fill", "figure.walk", "dumbbell.fill", "book.fill",
        "pencil", "music.note", "fork.knife", "brain.head.profile",
        "drop.fill", "leaf.fill", "flame.fill", "bolt.fill",
        "moon.fill", "sun.max.fill", "star.fill", "paintbrush.fill"
    ]

    private let quickDurations = [10, 15, 20, 30, 45, 60]

    private var isEditing: Bool { habit != nil }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    nameSection
                    iconSection
                    colorSection
                    durationSection
                    minimumDurationSection
                    preferredTimeSection
                    notesSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isEditing ? "Edit Habit" : "New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveHabit)
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
            TextField("Habit name", text: $name)
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
                    ForEach(Color.habitPresets.indices, id: \.self) { i in
                        let preset = Color.habitPresets[i]
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
                    Button(action: {
                        defaultDuration = d
                        if minimumDuration > d { minimumDuration = max(5, d / 2) }
                    }) {
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

    private var minimumDurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Minimum Duration")
                    .font(.headline)
                Spacer()
                Text("\(minimumDuration) min")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { Double(minimumDuration) },
                    set: { minimumDuration = Int($0) }
                ),
                in: 5...Double(max(defaultDuration, 5)),
                step: 5
            )
            .tint(selectedColor)
            Text("On hard days, this habit can be compressed to this minimum while still counting as \"showing up\"")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
    }

    private var preferredTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $hasPreferredTime) {
                HStack(spacing: 10) {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(selectedColor)
                    Text("Preferred Time")
                        .font(.headline)
                }
            }
            .tint(selectedColor)

            if hasPreferredTime {
                HStack {
                    Text("Hour")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Hour", selection: $preferredHour) {
                        ForEach(0..<24, id: \.self) { h in
                            Text(formatHour(h)).tag(h)
                        }
                    }
                    .pickerStyle(.menu)
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
        guard !hasInitialized, let h = habit else {
            hasInitialized = true
            return
        }
        hasInitialized = true
        name = h.name
        iconName = h.iconName
        selectedColor = Color(hex: h.colorHex) ?? .purple
        defaultDuration = h.defaultDurationMinutes
        minimumDuration = h.minimumDurationMinutes
        if let ph = h.preferredHour {
            hasPreferredTime = true
            preferredHour = ph
        }
        notes = h.notes ?? ""
    }

    private func saveHabit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let existing = habit {
            existing.name = trimmed
            existing.iconName = iconName
            existing.colorHex = selectedColor.toHex()
            existing.defaultDurationMinutes = defaultDuration
            existing.minimumDurationMinutes = min(minimumDuration, defaultDuration)
            existing.preferredHour = hasPreferredTime ? preferredHour : nil
            existing.notes = notes.isEmpty ? nil : notes
        } else {
            let h = HabitDefinition(
                name: trimmed,
                iconName: iconName,
                colorHex: selectedColor.toHex(),
                defaultDurationMinutes: defaultDuration,
                minimumDurationMinutes: min(minimumDuration, defaultDuration),
                preferredHour: hasPreferredTime ? preferredHour : nil,
                notes: notes.isEmpty ? nil : notes
            )
            modelContext.insert(h)
        }
        dismiss()
    }

    private func formatHour(_ h: Int) -> String {
        if h == 0 { return "12 AM" }
        if h == 12 { return "12 PM" }
        return h > 12 ? "\(h - 12) PM" : "\(h) AM"
    }
}

#Preview {
    HabitDefinitionEditView(habit: nil)
        .modelContainer(for: HabitDefinition.self, inMemory: true)
}
