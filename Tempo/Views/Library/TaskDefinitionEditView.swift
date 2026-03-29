import SwiftUI
import SwiftData

struct TaskDefinitionEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let task: TaskDefinition?

    @State private var title: String = ""
    @State private var iconName: String = "checkmark.circle.fill"
    @State private var selectedColor: Color = Color(hex: "#3B82F6") ?? .blue
    @State private var durationMinutes: Int = 30
    @State private var hasDeadline: Bool = false
    @State private var deadline: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var notes: String = ""
    @State private var hasInitialized = false

    private let iconOptions = [
        "checkmark.circle.fill", "doc.fill", "envelope.fill", "phone.fill",
        "cart.fill", "house.fill", "person.fill", "wrench.fill",
        "hammer.fill", "lightbulb.fill", "bolt.fill", "flag.fill",
        "tag.fill", "paperclip", "link", "calendar"
    ]

    private let quickDurations = [15, 30, 45, 60, 90, 120]

    private var isEditing: Bool { task != nil }
    private var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    titleSection
                    iconSection
                    colorSection
                    durationSection
                    deadlineSection
                    notesSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TITLE").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .foregroundStyle(selectedColor)
                    .font(.title3)
                    .frame(width: 32)
                TextField("Task name", text: $title)
                    .font(.body)
            }
            .padding()
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ICON").font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(iconOptions, id: \.self) { icon in
                        Button {
                            iconName = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.title3)
                                .foregroundStyle(iconName == icon ? .white : selectedColor)
                                .frame(width: 44, height: 44)
                                .background(iconName == icon ? selectedColor : selectedColor.opacity(0.12),
                                            in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .padding()
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COLOR").font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Color.taskPresets, id: \.self) { color in
                        Button {
                            selectedColor = color
                        } label: {
                            Circle()
                                .fill(color)
                                .frame(width: 36, height: 36)
                                .overlay {
                                    if selectedColor.toHex() == color.toHex() {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .padding()
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ESTIMATED DURATION").font(.caption).foregroundStyle(.secondary)
            VStack(spacing: 12) {
                Text("\(durationMinutes) min")
                    .font(.headline)
                    .foregroundStyle(selectedColor)
                HStack(spacing: 8) {
                    ForEach(quickDurations, id: \.self) { d in
                        Button {
                            durationMinutes = d
                        } label: {
                            Text(d < 60 ? "\(d)m" : "\(d / 60)h")
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(durationMinutes == d ? selectedColor : Color(.systemGray5),
                                            in: Capsule())
                                .foregroundStyle(durationMinutes == d ? .white : .primary)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var deadlineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DEADLINE").font(.caption).foregroundStyle(.secondary)
            VStack(spacing: 0) {
                Toggle("Set a deadline", isOn: $hasDeadline)
                    .padding()
                if hasDeadline {
                    Divider().padding(.leading)
                    DatePicker("", selection: $deadline, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding(.horizontal)
                        .tint(selectedColor)
                }
            }
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTES").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $notes)
                .frame(minHeight: 80)
                .padding(8)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Actions

    private func loadExisting() {
        guard !hasInitialized, let t = task else { hasInitialized = true; return }
        title = t.title
        iconName = t.iconName
        selectedColor = Color(hex: t.colorHex) ?? .blue
        durationMinutes = t.durationMinutes
        if let d = t.deadline {
            hasDeadline = true
            deadline = d
        }
        notes = t.notes ?? ""
        hasInitialized = true
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let existing = task {
            existing.title = trimmed
            existing.iconName = iconName
            existing.colorHex = selectedColor.toHex()
            existing.durationMinutes = durationMinutes
            existing.deadline = hasDeadline ? deadline : nil
            existing.notes = notes.isEmpty ? nil : notes
        } else {
            let newTask = TaskDefinition(
                title: trimmed,
                iconName: iconName,
                colorHex: selectedColor.toHex(),
                durationMinutes: durationMinutes,
                deadline: hasDeadline ? deadline : nil,
                notes: notes.isEmpty ? nil : notes
            )
            modelContext.insert(newTask)
        }
        dismiss()
    }
}
