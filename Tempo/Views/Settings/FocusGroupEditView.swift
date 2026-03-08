import SwiftUI
import FamilyControls

/// View for creating or editing a Focus Group (name, symbol, app selection).
struct FocusGroupEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var focusBlockManager: FocusBlockManager

    private let isEditing: Bool
    @State private var group: FocusGroup
    @State private var showingPicker = false

    private let symbolOptions = [
        "moon.circle.fill", "brain.fill", "bolt.circle.fill", "flame.fill",
        "target", "dumbbell.fill", "book.fill", "pencil.circle.fill",
        "deskclock.fill", "eye.circle.fill"
    ]

    init(group: FocusGroup?) {
        if let group {
            self.isEditing = true
            _group = State(initialValue: group)
        } else {
            self.isEditing = false
            _group = State(initialValue: FocusGroup(name: "", symbol: "moon.circle.fill"))
        }
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("e.g. Deep Work, Light Focus", text: $group.name)
            }

            Section("Icon") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(symbolOptions, id: \.self) { symbol in
                            Button {
                                group.symbol = symbol
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(group.symbol == symbol ? Color.indigo : Color(.systemGray5))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: symbol)
                                        .font(.system(size: 20))
                                        .foregroundColor(group.symbol == symbol ? .white : .primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Button {
                    showingPicker = true
                } label: {
                    HStack {
                        Label("Choose Apps & Categories", systemImage: "apps.iphone")
                        Spacer()
                        if group.blockedItemCount > 0 {
                            Text("\(group.blockedItemCount) selected")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)
            } header: {
                Text("Apps & Categories to Block")
            } footer: {
                Text("Select apps and categories that will be blocked during this focus session.")
                    .font(.caption)
            }
        }
        .navigationTitle(isEditing ? "Edit Group" : "New Group")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPicker) {
            NavigationStack {
                FamilyActivityPicker(selection: Binding(
                    get: { group.selection },
                    set: { group.selection = $0 }
                ))
                .navigationTitle("Choose Apps")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingPicker = false }
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
                    .disabled(group.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func save() {
        var saved = group
        saved.name = group.name.trimmingCharacters(in: .whitespaces)
        focusBlockManager.saveGroup(saved)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        FocusGroupEditView(group: nil)
            .environmentObject(FocusBlockManager())
    }
}
